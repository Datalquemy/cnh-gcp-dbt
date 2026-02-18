{{ config(
    materialized = 'incremental',
    unique_key = 'surrogate_key_audit',
    incremental_strategy = 'merge',
    alias = 'unknown_campos_audit'
) }}

WITH union_bronze AS (
    -- 1. UNIFICACIÓN: Traemos ambos dominios de Bronze
    SELECT 
        UPPER(TRIM(campo)) AS campo_norm,
        DATE(EXTRACT(YEAR FROM fecha), EXTRACT(MONTH FROM fecha), 1) AS month_start,
        source_filename,
        'OIL' AS domain
    FROM {{ ref('oil_production_bz') }}
    
    UNION ALL

    SELECT 
        UPPER(TRIM(campo)) AS campo_norm,
        DATE(EXTRACT(YEAR FROM fecha), EXTRACT(MONTH FROM fecha), 1) AS month_start,
        source_filename,
        'GAS' AS domain
    FROM {{ ref('gas_production_bz') }}
),

filtered_bronze AS (
   -- 2. COSTOS (PUERTAS): Lookback predecible basado en reloj (Opción B de Red)
   -- Esto garantiza que NUNCA escaneemos más de 24 meses, incluso si la tabla está vacía.
   SELECT * FROM union_bronze
   WHERE month_start >= DATE_SUB(CURRENT_DATE(), INTERVAL 24 MONTH)
),

catalog AS (
    -- 3. INTEGRIDAD: Nuestra fuente de verdad (Seed)
    SELECT UPPER(TRIM(campo)) AS campo FROM {{ ref('cat_campos_cnh') }}
),

unknown_detections AS (
    -- 4. DETECCIÓN: Solo lo que no existe en el catálogo
    SELECT
        b.domain,
        b.campo_norm,
        b.source_filename,
        COUNT(*) AS row_count,
        MIN(b.month_start) AS month_start_min,
        MAX(b.month_start) AS month_start_max
    FROM filtered_bronze b
    LEFT JOIN catalog c ON b.campo_norm = c.campo
    WHERE c.campo IS NULL 
    GROUP BY 1, 2, 3
),

final_pre_filter AS (
    -- 5. IDENTIDAD: Calculamos el Hash antes del filtro para evitar errores de scope
    SELECT
        TO_HEX(SHA256(CONCAT(domain, '|', campo_norm, '|', source_filename))) AS surrogate_key_audit,
        domain,
        campo_norm,
        source_filename,
        row_count,
        month_start_min,
        month_start_max,
        CURRENT_TIMESTAMP() AS first_detected_at,
        'NEW' AS action_status
    FROM unknown_detections
)

SELECT * FROM final_pre_filter t

{% if is_incremental() %}
    -- 6. IDEMPOTENCIA (RUEDAS): NOT EXISTS para evitar duplicados y proteger de NULLs
    WHERE NOT EXISTS (
        SELECT 1 
        FROM {{ this }} existing 
        WHERE t.surrogate_key_audit = existing.surrogate_key_audit
    )
{% endif %}