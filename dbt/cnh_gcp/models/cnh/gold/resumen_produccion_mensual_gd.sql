{{ config(
    materialized = 'table',
    tags = ['gold']
) }}

-- Gold mensual: totales y promedios por año/mes/cuenca/ubicacion/operador
WITH base AS (
    SELECT
        fecha,
        EXTRACT(YEAR  FROM fecha) AS anio,
        EXTRACT(MONTH FROM fecha) AS mes,
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
    mes,
    cuenca,
    ubicacion,
    operador,

    -- Totales del mes
    SUM(petroleo_mbd)               AS total_petroleo_mes,
    SUM(produccion_gas_total_mmpcd) AS total_gas_mes,
    SUM(condensado_mbd)            AS total_condensado_mes,

    -- Promedios diarios (para BI)
    SAFE_DIVIDE(SUM(petroleo_mbd),
                COUNT(DISTINCT fecha)) AS prom_diario_petroleo,
    SAFE_DIVIDE(SUM(produccion_gas_total_mmpcd),
                COUNT(DISTINCT fecha)) AS prom_diario_gas

FROM base
GROUP BY
    anio,
    mes,
    cuenca,
    ubicacion,
    operador
ORDER BY
    anio,
    mes,
    cuenca,
    ubicacion,
    operador