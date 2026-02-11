{{ config(
    materialized='incremental',
    incremental_strategy='merge', 
    on_schema_change='append_new_columns',
    partition_by={"field": "fecha", "data_type": "date", "granularity": "day"},
    cluster_by=["campo", "operador"],

    pre_hook=[
      "-- 1) CLAIM: Reclamar archivos del prefijo de OIL
      MERGE `{{ target.project }}.cnh_staging.bronze_cnh_manifest` AS m
      USING (
        SELECT 'oil' AS domain, uri AS source_filename, updated AS file_modified_at, md5_hash 
        FROM `{{ target.project }}.cnh_staging.obj_oil_inventory`
        WHERE uri LIKE '%/staging/cnh/oil/production/%.csv'
      ) AS s
      ON m.source_filename = s.source_filename AND m.domain = s.domain
      WHEN NOT MATCHED THEN
        INSERT (domain, source_filename, file_modified_at, md5_hash, status, run_id, claimed_at)
        VALUES (s.domain, s.source_filename, s.file_modified_at, s.md5_hash, 'processing', '{{ invocation_id }}', CURRENT_TIMESTAMP())
      WHEN MATCHED AND (m.file_modified_at < s.file_modified_at OR m.status IN ('failed', 'rejected', 'processed_with_errors') OR (m.status = 'processing' AND TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), m.claimed_at, MINUTE) > 60)) THEN
        UPDATE SET status = 'processing', run_id = '{{ invocation_id }}', claimed_at = CURRENT_TIMESTAMP(), file_modified_at = s.file_modified_at, md5_hash = s.md5_hash, error_message = NULL"
    ],

    post_hook=[
      "-- 2) COMMIT: Cierre robusto del manifiesto
      UPDATE `{{ target.project }}.cnh_staging.bronze_cnh_manifest` AS m
      SET 
        status = CASE WHEN t.row_count > 0 THEN 'processed' ELSE 'processed_with_errors' END,
        processed_at = CURRENT_TIMESTAMP(), 
        row_count_loaded = COALESCE(t.row_count, 0),
        error_message = CASE WHEN t.row_count IS NULL OR t.row_count = 0 THEN 'ALL_ROWS_REJECTED_OR_EMPTY' ELSE NULL END
      FROM (
          SELECT m_inner.source_filename, COUNT(this.source_filename) AS row_count
          FROM `{{ target.project }}.cnh_staging.bronze_cnh_manifest` m_inner
          LEFT JOIN {{ this }} this ON m_inner.source_filename = this.source_filename AND this.run_id = '{{ invocation_id }}'
          WHERE m_inner.run_id = '{{ invocation_id }}' AND m_inner.domain = 'oil'
          GROUP BY 1
      ) AS t
      WHERE m.source_filename = t.source_filename AND m.run_id = '{{ invocation_id }}' AND m.domain = 'oil';

      -- 3) LOGGING: Con COALESCE para evitar nulos en el reporte
      INSERT INTO `{{ target.project }}.cnh_staging.dq_run_log_bronze` 
      (run_id, domain, files_claimed, files_processed, files_rejected, rows_loaded, run_status, event_timestamp)
      SELECT 
        '{{ invocation_id }}', 'oil', COUNT(*),
        COUNTIF(status = 'processed'), COUNTIF(status = 'processed_with_errors'),
        COALESCE(SUM(row_count_loaded), 0), -- Ajuste Red Team
        'SUCCESS', CURRENT_TIMESTAMP()
      FROM `{{ target.project }}.cnh_staging.bronze_cnh_manifest`
      WHERE run_id = '{{ invocation_id }}' AND domain = 'oil';"
    ]
) }}

WITH raw_source AS (
  SELECT fecha AS fecha_raw, cuenca, ubicacion, campo, operador,
         petroleo_mbd AS petroleo_raw, liquidos_mbd AS liquidos_raw, condensado_mbd AS condensado_raw,
         _FILE_NAME AS source_filename
  FROM {{ source('cnh_staging', 'ext_oil_production_raw') }}
),
claimed_files AS (
  SELECT source_filename, file_modified_at FROM `{{ target.project }}.cnh_staging.bronze_cnh_manifest`
  WHERE run_id = '{{ invocation_id }}' AND status = 'processing' AND domain = 'oil'
),
casting AS (
  SELECT 
    r.*, 
    -- LÓGICA HÍBRIDA
    COALESCE(
        SAFE.PARSE_DATE('%d/%m/%Y', CAST(r.fecha_raw AS STRING)), 
        SAFE.PARSE_DATE('%Y-%m-%d', CAST(r.fecha_raw AS STRING)), 
        SAFE_CAST(r.fecha_raw AS DATE)                           
    ) AS parsed_date,
    SAFE_CAST(r.petroleo_raw AS NUMERIC) AS parsed_petroleo,
    c.file_modified_at -- Aquí traemos la columna de la tabla C
  FROM raw_source r
  INNER JOIN claimed_files c ON r.source_filename = c.source_filename
)
SELECT 
    parsed_date AS fecha, 
    cuenca, 
    ubicacion, 
    campo, 
    operador,
    parsed_petroleo AS petroleo_mbd, 
    SAFE_CAST(liquidos_raw AS NUMERIC) AS liquidos_mbd,
    SAFE_CAST(condensado_raw AS NUMERIC) AS condensado_mbd,
    source_filename, 
    file_modified_at, -- <--- AGREGA ESTA COMA
    '{{ invocation_id }}' AS run_id, 
    CURRENT_TIMESTAMP() AS ingestion_timestamp_utc
FROM casting
WHERE parsed_date IS NOT NULL AND parsed_petroleo IS NOT NULL