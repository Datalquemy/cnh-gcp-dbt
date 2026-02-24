## Reporte de Prueba #2: Ingesta Incremental (Febrero 2025)
Este reporte certifica que la carga de nuevos archivos generó un linaje limpio y un nuevo identificador de lote.
?? Query de Rastreo: ¿Dónde quedó el 2025?
Este query valida la presencia de los datos nuevos en todas las capas y la simetría de la unificación.

SQL


SELECT 
    '1. BRONZE_OIL' as capa, 
    COUNT(*) as filas, 
    MIN(fecha) as min_f, MAX(fecha) as max_f 
FROM `da-port-cnh-dev.cnh_bronze.oil_production_bz` 
WHERE fecha >= '2025-01-01'

UNION ALL

SELECT 
    '2. BRONZE_GAS' as capa, 
    COUNT(*) as filas, 
    MIN(fecha) as min_f, MAX(fecha) as max_f 
FROM `da-port-cnh-dev.cnh_bronze.gas_production_bz` 
WHERE fecha >= '2025-01-01'

UNION ALL

SELECT 
    '3. SILVER_UNIFICADA' as capa, 
    COUNT(*) as filas, 
    MIN(fecha) as min_f, MAX(fecha) as max_f 
FROM `da-port-cnh-dev.cnh_silver.produccion_unificada_sv` 
WHERE fecha >= '2025-01-01';

??? Query de Auditoría de Linaje (Silver vs. Manifiesto)
Utilizado para demostrar que cada fila en la Unificada tiene un "acta de nacimiento" en el Manifiesto de Control.

SQL


WITH silver_metrics AS (
    -- Métricas de la tabla Unificada: Aquí consolidamos la identidad de los lotes
    SELECT 
        'UNIFICADA_SV' AS tabla,
        _batch_id AS run_id,
        MIN(fecha) AS fecha_datos_min,
        MAX(fecha) AS fecha_datos_max,
        COUNT(*) AS total_registros
    FROM `da-port-cnh-dev.cnh_silver.produccion_unificada_sv`
    GROUP BY 1, 2
)
SELECT 
    m.domain AS dominio,
    s.tabla,
    s.run_id,
    m.source_filename AS archivo_origen,
    m.claimed_at AS fecha_ingestion_bz, 
    s.fecha_datos_min,
    s.fecha_datos_max,
    s.total_registros,
    m.status AS estatus_manifiesto
FROM silver_metrics s
INNER JOIN `da-port-cnh-dev.cnh_staging.bronze_cnh_manifest` m
  ON s.run_id = m.run_id
ORDER BY fecha_ingestion_bz DESC, dominio;

?? Informe de Validación: Ajuste de Cuenca y Catálogo
Este informe documenta por qué se incluyó la Cuenca en los joins para resolver el caso del campo CAPARROSO PIJIJE ESCUINTLE.
1. Verificación de Paridad (Bronze vs Silver Oil)

SQL


WITH bronze_count AS (
  SELECT COUNT(*) AS OIL_BZ 
  FROM `da-port-cnh-dev.cnh_bronze.oil_production_bz`
  WHERE COALESCE(petroleo_mbd, 0) >= 0
    AND COALESCE(liquidos_mbd, 0) >= 0
    AND COALESCE(condensado_mbd, 0) >= 0
),
silver_count AS (
  SELECT COUNT(*) AS OIL_SV 
  FROM `da-port-cnh-dev.cnh_silver.oil_production_sv`
)
SELECT 
  b.OIL_BZ AS BZ, 
  s.OIL_SV AS SV
FROM bronze_count b, silver_count s;

? Resultado obtenido: BZ: 211,267 | SV: 211,267 (Paridad 1:1).
2. Diagnóstico del Embudo de Transformación (Paso a Paso)
Query completo para identificar dónde se filtraban o duplicaban los registros.

SQL


WITH 
-- 1. Lo que hay en Bronze (Punto de partida)
paso_bronze AS (
    SELECT COUNT(*) as total FROM `da-port-cnh-dev.cnh_bronze.oil_production_bz`
    WHERE fecha < '2025-01-01'
),

-- 2. Filtro de Negativos (src_oil)
paso_negativos AS (
    SELECT COUNT(*) as total
    FROM `da-port-cnh-dev.cnh_bronze.oil_production_bz`
    WHERE fecha < '2025-01-01'
    AND COALESCE(petroleo_mbd, 0) >= 0 
    AND COALESCE(liquidos_mbd, 0) >= 0 
    AND COALESCE(condensado_mbd, 0) >= 0
),

-- 3. Filtro de Catálogo (refined con JOIN por Cuenca)
paso_catalogo AS (
    SELECT COUNT(*) as total
    FROM `da-port-cnh-dev.cnh_bronze.oil_production_bz` s
    INNER JOIN `da-port-cnh-dev.cnh_silver.cat_campos_cnh` c 
      ON UPPER(TRIM(s.campo)) = c.campo 
      AND UPPER(TRIM(s.cuenca)) = c.cuenca
    WHERE s.fecha < '2025-01-01'
    AND COALESCE(s.petroleo_mbd, 0) >= 0 
),

-- 4. Filtro de Deduplicación (id_registro_unico)
paso_dedupe AS (
    SELECT COUNT(DISTINCT id_registro_unico) as total
    FROM (
        SELECT 
            FARM_FINGERPRINT(CONCAT(
                EXTRACT(YEAR FROM s.fecha), 
                EXTRACT(MONTH FROM s.fecha), 
                c.cuenca, 
                c.ubicacion, 
                UPPER(TRIM(s.campo)), 
                UPPER(TRIM(s.operador))
            )) as id_registro_unico
        FROM `da-port-cnh-dev.cnh_bronze.oil_production_bz` s
        INNER JOIN `da-port-cnh-dev.cnh_silver.cat_campos_cnh` c 
          ON UPPER(TRIM(s.campo)) = c.campo 
          AND UPPER(TRIM(s.cuenca)) = c.cuenca
        WHERE s.fecha < '2025-01-01'
        AND COALESCE(s.petroleo_mbd, 0) >= 0
    )
)
SELECT 
    (SELECT total FROM paso_bronze) as total_en_bronze,
    (SELECT total FROM paso_negativos) as despues_de_negativos,
    (SELECT total FROM paso_catalogo) as despues_de_catalogo,
    (SELECT total FROM paso_dedupe) as despues_de_deduplicar;

3. Validación Final Post-Refresh (Histórico)

SQL


SELECT 
    '1. OIL_SV' as capa, 
    COUNT(*) as total_filas, 
    MIN(fecha) as min_f, MAX(fecha) as max_f
FROM `da-port-cnh-dev.cnh_silver.oil_production_sv`
WHERE fecha < '2025-01-01'

UNION ALL

SELECT 
    '2. GAS_SV' as capa, 
    COUNT(*) as total_filas, 
    MIN(fecha) as min_f, MAX(fecha) as max_f
FROM `da-port-cnh-dev.cnh_silver.gas_production_sv`
WHERE fecha < '2025-01-01'

UNION ALL

SELECT 
    '3. UNIFICADA_SV' as capa, 
    COUNT(*) as total_filas, 
    MIN(fecha) as min_f, MAX(fecha) as max_f
FROM `da-port-cnh-dev.cnh_silver.produccion_unificada_sv`
WHERE fecha < '2025-01-01';

Nota Técnica: Con este ajuste, el clustering por cuenca y el join dimensional garantizan que el campo Caparroso reporte correctamente sus cifras en ambas regiones geográficas sin pérdida ni duplicidad de datos.

