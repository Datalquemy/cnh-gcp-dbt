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

WITH oil AS (
    SELECT * FROM {{ ref('oil_production_sv') }}
    {% if is_incremental() %}
      WHERE fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 24 MONTH)
    {% endif %}
),

gas AS (
    SELECT * FROM {{ ref('gas_production_sv') }}
    {% if is_incremental() %}
      WHERE fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 24 MONTH)
    {% endif %}
)

SELECT
    -- 1. CONGELADO: Llave Primaria
    COALESCE(o.id_registro_unico, g.id_registro_unico) AS id_registro_unico,

    -- 2. CONGELADO: Dimensiones
    COALESCE(o.fecha,     g.fecha)     AS fecha,
    COALESCE(o.anio,      g.anio)      AS anio,
    COALESCE(o.mes,       g.mes)       AS mes,
    COALESCE(o.cuenca,    g.cuenca)    AS cuenca,
    COALESCE(o.ubicacion, g.ubicacion) AS ubicacion,
    COALESCE(o.campo,     g.campo)     AS campo,
    COALESCE(o.operador,  g.operador)  AS operador,

    -- 3. CONGELADO: Métricas
    COALESCE(o.petroleo_mbd, 0)   AS petroleo_mbd,
    COALESCE(o.liquidos_mbd, 0)   AS liquidos_mbd,
    COALESCE(o.condensado_mbd, 0) AS condensado_mbd,
    COALESCE(g.gas_mmpcd, 0)      AS gas_mmpcd,
    COALESCE(g.nitrogeno_mmpcd, 0) AS nitrogeno_mmpcd,

    -- 4. CONGELADO: Flags
    IF(o.id_registro_unico IS NOT NULL, TRUE, FALSE) AS has_oil,
    IF(g.id_registro_unico IS NOT NULL, TRUE, FALSE) AS has_gas,

    -- 5. BLINDAJE (Puntos Red Team): Auditoría con Types Correctos
    GREATEST(
        COALESCE(o._ingestion_timestamp_utc, TIMESTAMP('1900-01-01 00:00:00')), 
        COALESCE(g._ingestion_timestamp_utc, TIMESTAMP('1900-01-01 00:00:00'))
    ) AS _ingestion_timestamp_utc,
    
    CONCAT(
        COALESCE(o._source_filename, 'NO_OIL'), 
        ' | ', 
        COALESCE(g._source_filename, 'NO_GAS')
    ) AS _source_filenames,
    
    COALESCE(o._batch_id, g._batch_id) AS _batch_id,
    CURRENT_TIMESTAMP() AS sv_unification_at

FROM oil o
FULL OUTER JOIN gas g ON o.id_registro_unico = g.id_registro_unico