{{ config(
    materialized = 'table',
    partition_by = {"field": "fecha", "data_type": "date"},
    cluster_by = ["campo", "operador"]
) }}

WITH src AS (
    SELECT
        fecha,
        cuenca,
        ubicacion,
        campo,
        operador,
        petroleo_mbd,
        liquidos_mbd,
        condensado_mbd
    FROM {{ ref('oil_production_bz') }}
)

SELECT
    fecha,
    cuenca,
    ubicacion,
    campo,
    operador,


    COALESCE(petroleo_mbd, 0)   AS petroleo_mbd,
    COALESCE(liquidos_mbd, 0)   AS liquidos_mbd,
    COALESCE(condensado_mbd, 0) AS condensado_mbd

FROM src
