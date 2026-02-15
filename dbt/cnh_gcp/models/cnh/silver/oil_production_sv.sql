{{ config(
    materialized = 'incremental',
    unique_key = 'id_registro_unico',
    incremental_strategy = 'merge',
    partition_by = {
      "field": "fecha",
      "data_type": "date",
      "granularity": "month"
    },
    cluster_by = ["campo", "operador"]
) }}

WITH src_oil AS (
    SELECT
        *,
        -- Normalizaciones de entrada (UPPER/TRIM)
        UPPER(TRIM(campo))     AS campo_norm,
        UPPER(TRIM(operador))  AS operador_norm,
        
        --  month_start canónico para Grain y Watermark
        DATE(EXTRACT(YEAR FROM fecha), EXTRACT(MONTH FROM fecha), 1) AS month_start
    FROM {{ ref('oil_production_bz') }}
    
    -- 🛡️ REJECT: No negativos (Regla de Contrato v3.1)
    WHERE petroleo_mbd >= 0 
      AND liquidos_mbd >= 0 
      AND condensado_mbd >= 0

    {% if is_incremental() %}
      -- Watermark autónomo con Sentinel Date 1900-01-01
      AND DATE(EXTRACT(YEAR FROM fecha), EXTRACT(MONTH FROM fecha), 1) >= DATE_SUB(
        COALESCE((SELECT MAX(fecha) FROM {{ this }}), DATE '1900-01-01'), 
        INTERVAL 24 MONTH
      )
    {% endif %}
),

catalog AS (
    -- GOBERNANZA: Solo campos permitidos en el Seed
    SELECT 
        UPPER(TRIM(campo)) AS campo, 
        UPPER(TRIM(cuenca)) AS cuenca_canonical, 
        UPPER(TRIM(ubicacion)) AS ubicacion_canonical
    FROM {{ ref('cat_campos_cnh') }}
),

refined AS (
    SELECT
        s.month_start AS fecha,
        EXTRACT(YEAR FROM s.month_start) AS anio,
        EXTRACT(MONTH FROM s.month_start) AS mes,
        c.cuenca_canonical AS cuenca,
        c.ubicacion_canonical AS ubicacion,
        s.campo_norm AS campo,
        s.operador_norm AS operador,
        
        -- Métricas limpias
        COALESCE(s.petroleo_mbd, 0)   AS petroleo_mbd,
        COALESCE(s.liquidos_mbd, 0)   AS liquidos_mbd,
        COALESCE(s.condensado_mbd, 0) AS condensado_mbd,
        
        -- Auditoría
        s.ingestion_timestamp_utc AS _ingestion_timestamp_utc,
        s.source_filename AS _source_filename,
        s.run_id AS _batch_id
    FROM src_oil s
    INNER JOIN catalog c ON s.campo_norm = c.campo -- REJECT fields out of domain
),

dedupe AS (
    -- DETERMINISMO: Tie-breaker por ingestión (v3.1)
    SELECT *, 
        ROW_NUMBER() OVER (
            PARTITION BY anio, mes, cuenca, ubicacion, campo, operador 
            ORDER BY _ingestion_timestamp_utc DESC, _source_filename DESC
        ) AS rn
    FROM refined
)

SELECT 
    * EXCEPT(rn),
    -- Surrogate Key como STRING HEX (Blindaje BigQuery)
    TO_HEX(SHA256(CONCAT(
        CAST(anio AS STRING), '|', 
        LPAD(CAST(mes AS STRING), 2, '0'), '|', 
        cuenca, '|', 
        ubicacion, '|', 
        campo, '|', 
        operador
    ))) AS id_registro_unico,
    CURRENT_TIMESTAMP() AS sv_ingestion_at
FROM dedupe 
WHERE rn = 1