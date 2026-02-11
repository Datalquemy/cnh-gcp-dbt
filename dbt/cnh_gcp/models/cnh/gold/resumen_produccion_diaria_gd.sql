{{ config(
    materialized = 'table',
    tags = ['gold']
) }}

-- Gold diario: totales nacionales por fecha
WITH base AS (
    SELECT
        fecha,
        petroleo_mbd,
        condensado_mbd,
        produccion_gas_total_mmpcd
    FROM {{ ref('produccion_unificada_sv') }}
)

SELECT
    fecha,
    SUM(petroleo_mbd)              AS total_petroleo_mbd,
    SUM(produccion_gas_total_mmpcd) AS total_gas_mmpcd,
    SUM(condensado_mbd)            AS total_condensado_mbd
FROM base
GROUP BY
    fecha
ORDER BY
    fecha