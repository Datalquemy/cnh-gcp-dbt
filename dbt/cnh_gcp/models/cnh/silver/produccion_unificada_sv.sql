{{ config(
    materialized = 'table',
    partition_by = {"field": "fecha", "data_type": "date"},
    cluster_by = ["campo", "operador"]
) }}

-- Silver – Producción unificada Oil + Gas

WITH oil AS (
    SELECT
        fecha,
        cuenca,
        ubicacion,
        campo,
        operador,
        petroleo_mbd,
        liquidos_mbd,
        condensado_mbd
    FROM {{ ref('oil_production_sv') }}
),

gas AS (
    SELECT
        fecha,
        cuenca,
        ubicacion,
        campo,
        operador,
        gas_natural_sin_nitrogeno_mmpcd,
        nitrogeno_mmpcd
    FROM {{ ref('gas_production_sv') }}
)

SELECT
    -- Claves unificadas
    COALESCE(o.fecha,     g.fecha)     AS fecha,
    COALESCE(o.cuenca,    g.cuenca)    AS cuenca,
    COALESCE(o.ubicacion, g.ubicacion) AS ubicacion,
    COALESCE(o.campo,     g.campo)     AS campo,
    COALESCE(o.operador,  g.operador)  AS operador,

    -- Métricas Oil
    o.petroleo_mbd,
    o.liquidos_mbd,
    o.condensado_mbd,

    -- Métricas Gas
    g.gas_natural_sin_nitrogeno_mmpcd,
    g.nitrogeno_mmpcd,

    -- Derivados Silver (base para KPIs Gold)
    (COALESCE(o.petroleo_mbd, 0) + COALESCE(o.condensado_mbd, 0))
        AS produccion_liquidos_total_mbd,
    (COALESCE(g.gas_natural_sin_nitrogeno_mmpcd, 0) + COALESCE(g.nitrogeno_mmpcd, 0))
        AS produccion_gas_total_mmpcd

FROM oil o
FULL OUTER JOIN gas g
    ON  o.fecha     = g.fecha
    AND o.campo     = g.campo
    AND o.operador  = g.operador
    AND o.cuenca    = g.cuenca
    AND o.ubicacion = g.ubicacion
