Plan bronze dbt

Buenísimo que ya volvió a conectar, Dr. Emmanuel 🔥
Ahora sí tiene sentido planear **Bronze con dbt** bien amarrado al contrato `bronze_cnh_v1.json` y al plan inicial de GCP.

Te voy a dar el **plan estratégico** de Bronze con dbt, pensado para irlo ejecutando paso a paso (sin meternos todavía a pegar todo el SQL).

---

## 🧭 0. Recordatorio rápido de la meta Bronze (con contrato en mano)

Según `bronze_cnh_v1.json`, Bronze debe:

* Trabajar el **dominio CNH**, stage **BRONZE** ✅

* Crear dos targets:

  * `bronze_oil_production`
  * `bronze_gas_production`

* Con:

  * **Partitioning:** por `fecha` (`BY_DATE`)
  * **Clustering:** por `campo`, `operador`
  * **Schema oil:**

    * `fecha` (DATE)
    * `cuenca`, `ubicacion`, `campo`, `operador` (STRING)
    * `petroleo_mbd`, `liquidos_mbd`, `condensado_mbd` (NUMERIC/FLOAT64)
  * **Schema gas:**

    * `fecha`, `cuenca`, `ubicacion`, `campo`, `operador`
    * `gas_natural_sin_nitrogeno_mmpcd`, `nitrogeno_mmpcd` (NUMERIC/FLOAT64)

* Reglas DQ:

  * `keep_all_rows: true` → **no filtramos filas en Bronze**
  * `reject_negative_measures: true` → se valida, pero idealmente **se registra en DQ**, no se mutila historia
  * `type_cast_mode: STRICT` → casts explícitos, sin inventar.

Con eso en mente, Bronze con dbt es:

> “Tomar las tablas externas de `cnh_staging`, tiparlas bien, particionarlas, clusterizarlas y dejar todo listo para Silver, sin reglas de negocio”.

---

## 1️⃣ Dataset y esquema objetivo en BigQuery

**Meta técnica en GCP:**

* Dataset físico destino: `cnh_bronze`
* Tablas físicas (desde dbt):

  * `cnh_bronze.oil_production_bz`
  * `cnh_bronze.gas_production_bz`

👉 Aunque el contrato use nombres lógicos `oil_production` / `gas_production`, en dbt podemos usar sufijo `_bz` como convención interna. Lo importante es que el **schema de columnas** coincida 100% con el contrato.

🎯 **Paso a ejecutar antes de correr dbt:**

* Verificar (o crear) en BigQuery el dataset:

  * `cnh_bronze`
  * Misma región: `us-central1`

---

## 2️⃣ Ajuste fino de configuración de dbt para Bronze

### 2.1 `profiles.yml` (ya lo tienes casi listo)

* `project: da-port-cnh-dev` ✅
* `dataset: cnh_staging` → esto está bien como **schema por defecto**, porque:

  * Los modelos van a sobrescribir el schema a `cnh_bronze`.
  * `cnh_staging` se usa solo para leer `source()`.

No hay que mover aquí nada crítico por ahora.

---

### 2.2 `dbt_project.yml` – decirle a dbt dónde están los modelos y cómo tratarlos

Aquí el plan es:

* Definir que los modelos viven en `models/cnh`.
* Definir que **Bronze se materializa como TABLE** en el dataset `cnh_bronze`.
* Dejar ya apartadas las rutas para Silver y Gold (aunque las llenemos después).

Estrategia de configuración (conceptual):

* Bloque `models:` en `dbt_project.yml`:

  * `models.cnh_gcp.cnh.staging`

    * Solo sources (no materializan nada).
  * `models.cnh_gcp.cnh.bronze`

    * `+schema: cnh_bronze`
    * `+materialized: table`
  * `models.cnh_gcp.cnh.silver`

    * (futuro) → `+schema: cnh_silver`
  * `models.cnh_gcp.cnh.gold`

    * (futuro) → `+schema: cnh_gold`

Con esto, cualquier modelo `.sql` dentro de `models/cnh/bronze` va directo a `cnh_bronze`.

---

## 3️⃣ Sources de Staging (ya casi los tienes)

En `models/cnh/staging/_sources.yml` ya definimos algo así conceptualmente:

* `source: cnh_staging`
* `tables: oil_production_ext`, `gas_production_ext`

Estrategia:

* Estos `source()` son la **traducción directa** de la sección `"sources"` del contrato JSON.
* A futuro, aquí mismo puedes agregar:

  * Descripciones de columnas.
  * Tests de:

    * `not_null` en claves.
    * `accepted_values` (si aplica).
    * etc.

Pero por ahora, lo clave es que mañana Bronze use:

```sql
{{ source('cnh_staging', 'oil_production_ext') }}
{{ source('cnh_staging', 'gas_production_ext') }}
```

en lugar de usar nombres “hardcoded”.

---

## 4️⃣ Diseño del modelo Bronze – Oil (`oil_production_bz`)

### 4.1 Ubicación del modelo

Archivo:

```text
models/cnh/bronze/oil_production_bz.sql
```

### 4.2 Lógica alineada al contrato

Objetivo: implementar el target `bronze_oil_production` del JSON, con la convención `_bz`.

* **FROM**: `{{ source('cnh_staging', 'oil_production_ext') }}`
* **SELECT**:

  * `CAST(fecha AS DATE) AS fecha`
  * `cuenca` (STRING)
  * `ubicacion` (STRING)
  * `campo` (STRING)
  * `operador` (STRING)
  * `CAST(petroleo_mbd AS FLOAT64) AS petroleo_mbd`
  * `CAST(liquidos_mbd AS FLOAT64) AS liquidos_mbd`
  * `CAST(condensado_mbd AS FLOAT64) AS condensado_mbd`

⚠️ **NO hacer todavía:**

* `WHERE liquidos_mbd > 0` ❌
* `COALESCE(condensado_mbd, 0)` ❌
* Mezcla con gas ❌

Solo **tipado y estructura**.

### 4.3 Partición y clustering

Configurar (a nivel modelo):

* `partition_by` → columna `fecha`
* `cluster_by` → `["campo", "operador"]`

Esto respeta la sección `"partitioning"` y `"clustering"` del contrato.

---

## 5️⃣ Diseño del modelo Bronze – Gas (`gas_production_bz`)

Archivo:

```text
models/cnh/bronze/gas_production_bz.sql
```

Lógica similar:

* **FROM**: `{{ source('cnh_staging', 'gas_production_ext') }}`

* **SELECT**:

  * `CAST(fecha AS DATE) AS fecha`
  * `cuenca`, `ubicacion`, `campo`, `operador`
  * `CAST(gas_natural_sin_nitrogeno_mmpcd AS FLOAT64) AS gas_natural_sin_nitrogeno_mmpcd`
  * `CAST(nitrogeno_mmpcd AS FLOAT64) AS nitrogeno_mmpcd`

Mismas reglas:

* Sin filtros.
* Sin reemplazo de nulos.
* Mismas configs de `partition_by` y `cluster_by`.

---

## 6️⃣ Reglas de DQ del contrato (cómo las interpretamos en dbt)

El contrato dice:

* `keep_all_rows: true`
  → En dbt: **NO usamos WHERE para limpiar filas** en Bronze.

* `reject_negative_measures: true`
  → Estrategia:

  * En Bronze: **no tiramos filas**, pero podemos:

    * Agregar tests en YAML del tipo:

      * `test: value >= 0` para ciertas columnas.
    * O dejarlo como futura tarea DQ en `cnh_silver` o `dq_*`.

* `type_cast_mode: "STRICT"`
  → En dbt: todos los casts son explícitos (`CAST(... AS FLOAT64)`), sin confiar en inferencias.

Más adelante podemos añadir modelos/tests de DQ que escriban en la `log_table` del contrato `dq.dq_run_log_bronze`.
Por ahora, lo importante es no violar esos principios.

---

## 7️⃣ Validaciones que vamos a usar después de `dbt run`

Cuando tengamos listos los modelos y corramos:

```bash
dbt run -m oil_production_bz gas_production_bz
```

Las validaciones clave serán:

1. **Conteo de filas**

   * `SELECT COUNT(*) FROM cnh_staging.oil_production_ext`
   * `SELECT COUNT(*) FROM cnh_bronze.oil_production_bz`
     → Deben ser iguales.

2. **Rango de fechas**

   * `MIN(fecha)` y `MAX(fecha)` en Bronze
     → Deben conservar los años viejos (196x, 197x…), sin cortarlos como pasó en Python con el `> 0`.

3. **Esquema**

   * Revisar desde BigQuery que tipos coincidan:

     * `DATE` para fecha.
     * `STRING` para claves.
     * `FLOAT64/NUMERIC` para medidas.

4. **Spot check de valores**

   * Verificar manualmente algunos registros viejos con valores pequeños en producción para asegurarnos que no se han perdido por error de CAST.

---

## 8️⃣ Plan de ejecución para hoy / próxima sesión

Te propongo que el flujo con dbt sea:

1. Verificar que `dbt debug` sigue en **OK** ✅

2. Confirmar que `cnh_bronze` existe en BigQuery.

3. Ajustar `dbt_project.yml` para apuntar a `models/cnh` y dar config a `bronze`.

4. Crear `oil_production_bz.sql` y `gas_production_bz.sql` (siguiendo contrato).

5. Correr:

   ```bash
   dbt ls
   dbt run -m oil_production_bz gas_production_bz
   ```

6. Validar conteos, fechas y esquema en BigQuery.

7. Anotar todo en tu `GCP_ETL_PHASE2_BRONZE_DBT.md` como checkpoint.

---

Si quieres, en el siguiente mensaje te dejo ya:

* El **esqueleto exacto de `dbt_project.yml` para cnh/bronze**
* Y los **templates de los dos modelos `.sql`**, ya listos para copiar/pegar y correr.


SE CAMBIO FLOAT POR  NUMERIC