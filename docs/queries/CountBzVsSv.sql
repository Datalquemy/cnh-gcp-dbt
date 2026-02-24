--Cuenta cuantos registros hay de bronze vs silver en oil
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
