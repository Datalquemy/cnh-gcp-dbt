{{ config(
    materialized = 'table',
    partition_by = {"field": "fecha", "data_type": "date"},
    cluster_by = ["campo", "operador"]
) }}

-- Silver – Producción de gas
-- Limpieza ligera: COALESCE de métricas numéricas, sin tocar negativos

WITH src AS (
    SELECT
        fecha,
        cuenca,
        ubicacion,
        campo,
        operador,
        gas_natural_sin_nitrogeno_mmpcd,
        nitrogeno_mmpcd
    FROM {{ ref('gas_production_bz') }}
)

SELECT
    fecha,
    cuenca,
    ubicacion,
    campo,
    operador,

    COALESCE(gas_natural_sin_nitrogeno_mmpcd, 0) AS gas_natural_sin_nitrogeno_mmpcd,
    COALESCE(nitrogeno_mmpcd, 0)                 AS nitrogeno_mmpcd

FROM src
