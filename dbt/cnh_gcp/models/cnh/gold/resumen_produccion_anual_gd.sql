{{ config(
    materialized = 'table',
    tags = ['gold']
) }}

-- Gold anual: totales por año/cuenca/ubicacion/operador
WITH base AS (
    SELECT
        EXTRACT(YEAR FROM fecha) AS anio,
        cuenca,
        ubicacion,
        operador,
        petroleo_mbd,
        condensado_mbd,
        produccion_gas_total_mmpcd
    FROM {{ ref('produccion_unificada_sv') }}
)

SELECT
    anio,
    cuenca,
    ubicacion,
    operador,

    SUM(petroleo_mbd)               AS total_petroleo_anual,
    SUM(produccion_gas_total_mmpcd) AS total_gas_anual,
    SUM(condensado_mbd)            AS total_condensado_anual

FROM base
GROUP BY
    anio,
    cuenca,
    ubicacion,
    operador
ORDER BY
    anio,
    cuenca,
    ubicacion,
    operador