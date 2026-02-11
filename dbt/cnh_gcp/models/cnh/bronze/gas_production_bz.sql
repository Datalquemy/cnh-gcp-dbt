{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    partition_by={"field": "fecha", "data_type": "date", "granularity": "day"},
    cluster_by=["campo", "operador"],

    pre_hook=[
      "
      -- 1) CLAIM: Reclamar archivos del prefijo de GAS usando la Object Table
      MERGE `{{ target.project }}.cnh_staging.bronze_cnh_manifest` AS m
      USING (
        SELECT 
          'gas' AS domain,
          uri AS source_filename,
          updated AS file_modified_at,
          md5_hash 
        FROM `{{ target.project }}.cnh_staging.obj_gas_inventory`
        WHERE uri LIKE '%/staging/cnh/gas/production/%.csv'
      ) AS s
      ON m.source_filename = s.source_filename AND m.domain = s.domain
      
      WHEN NOT MATCHED THEN
        INSERT (domain, source_filename, file_modified_at, md5_hash, status, run_id, claimed_at)
        VALUES (s.domain, s.source_filename, s.file_modified_at, s.md5_hash, 'processing', '{{ invocation_id }}', CURRENT_TIMESTAMP())
      
      WHEN MATCHED AND (m.file_modified_at < s.file_modified_at OR m.status IN ('failed', 'rejected', 'processed_with_errors') OR (m.status = 'processing' AND TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), m.claimed_at, MINUTE) > 60)) THEN
        UPDATE SET 
            status = 'processing', 
            run_id = '{{ invocation_id }}', 
            claimed_at = CURRENT_TIMESTAMP(),
            file_modified_at = s.file_modified_at,
            md5_hash = s.md5_hash,
            error_message = NULL
      "
    ],

    post_hook=[
      "
      -- 2) COMMIT ROBUSTO: Cerramos el manifiesto usando LEFT JOIN
      UPDATE `{{ target.project }}.cnh_staging.bronze_cnh_manifest` AS m
      SET 
        status = CASE WHEN t.row_count > 0 THEN 'processed' ELSE 'processed_with_errors' END,
        processed_at = CURRENT_TIMESTAMP(), 
        row_count_loaded = COALESCE(t.row_count, 0),
        error_message = CASE WHEN t.row_count IS NULL OR t.row_count = 0 THEN 'ALL_ROWS_REJECTED_OR_EMPTY' ELSE NULL END
      FROM (
          SELECT m_inner.source_filename, COUNT(this.source_filename) AS row_count
          FROM `{{ target.project }}.cnh_staging.bronze_cnh_manifest` m_inner
          LEFT JOIN {{ this }} this 
            ON m_inner.source_filename = this.source_filename 
            AND this.run_id = '{{ invocation_id }}'
          WHERE m_inner.run_id = '{{ invocation_id }}' AND m_inner.domain = 'gas'
          GROUP BY 1
      ) AS t
      WHERE m.source_filename = t.source_filename 
        AND m.run_id = '{{ invocation_id }}'
        AND m.domain = 'gas';

      -- 3) LOGGING: Registro en cnh_staging.dq_run_log_bronze
      INSERT INTO `{{ target.project }}.cnh_staging.dq_run_log_bronze` 
      (run_id, domain, files_claimed, files_processed, files_rejected, rows_loaded, run_status, event_timestamp)
      SELECT 
        '{{ invocation_id }}', 
        'gas', 
        COUNT(*),
        COUNTIF(status = 'processed'),
        COUNTIF(status = 'processed_with_errors'),
        COALESCE(SUM(row_count_loaded), 0),
        'SUCCESS',
        CURRENT_TIMESTAMP()
      FROM `{{ target.project }}.cnh_staging.bronze_cnh_manifest`
      WHERE run_id = '{{ invocation_id }}' AND domain = 'gas';
      "
    ]
) }}

WITH raw_source AS (
  -- PASILLO DE STRINGS: Leemos como raw para evitar que BigQuery infiera tipos
  SELECT
    fecha AS fecha_raw,
    cuenca,
    ubicacion,
    campo,
    operador,
    gas_natural_sin_nitrogeno_mmpcd AS gas_raw,
    nitrogeno_mmpcd AS nitrogeno_raw,
    _FILE_NAME AS source_filename
  FROM {{ source('cnh_staging', 'ext_gas_production_raw') }}
),

claimed_files AS (
  SELECT source_filename, file_modified_at
  FROM `{{ target.project }}.cnh_staging.bronze_cnh_manifest`
  WHERE run_id = '{{ invocation_id }}' AND status = 'processing' AND domain = 'gas'
),

casting AS (
  SELECT
    r.*,
    -- LÓGICA HÍBRIDA: El estándar que ya nos dio el PASS en Oil
    COALESCE(
        SAFE.PARSE_DATE('%d/%m/%Y', CAST(r.fecha_raw AS STRING)), -- Formato Contrato
        SAFE.PARSE_DATE('%Y-%m-%d', CAST(r.fecha_raw AS STRING)), -- Formato ISO
        SAFE_CAST(r.fecha_raw AS DATE)                           -- Cast directo
    ) AS parsed_date,
    SAFE_CAST(r.gas_raw AS NUMERIC) AS parsed_gas,
    c.file_modified_at
  FROM raw_source r
  INNER JOIN claimed_files c ON r.source_filename = c.source_filename
)

SELECT
    parsed_date AS fecha,
    cuenca,
    ubicacion,
    campo,
    operador,
    parsed_gas AS gas_natural_sin_nitrogeno_mmpcd,
    SAFE_CAST(nitrogeno_raw AS NUMERIC) AS nitrogeno_mmpcd,
    source_filename,
    file_modified_at,
    '{{ invocation_id }}' AS run_id,
    CURRENT_TIMESTAMP() AS ingestion_timestamp_utc
FROM casting
WHERE parsed_date IS NOT NULL 
  AND parsed_gas IS NOT NULL