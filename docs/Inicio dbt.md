Inicio dbt
---

## 1️⃣ Estructura recomendada en tu D:\Multinube

Partiendo de lo que ya tienes en las fotos, la idea es **no romper nada**, solo **añadir la capa dbt** bien ordenada.

```text
D:\Multinube
├── cloud
│   ├── aws
│   ├── azure
│   └── gcp
│       ├── bigquery_sql      ← SQL “suelto” que ya tenemos (lo dejamos vivo)
│       ├── terraform
│       └── dbt               ← NUEVO
│           └── cnh_gcp       ← Proyecto dbt para CNH en BigQuery
│
├── contracts
│   ├── bi
│   ├── domains
│   ├── dq
│   ├── lake                  ← Aquí vive bronze_cnh_v1.json, etc.
│   ├── metadata
│   ├── ml
│   └── orquestation
├── data
├── docs
├── notebooks
├── scripts
└── secrets_local
```

Más adelante, cuando toquemos AWS/Azure:

```text
D:\Multinube\cloud\aws\dbt\cnh_aws
D:\Multinube\cloud\azure\dbt\cnh_azure
```

Pero **hoy solo trabajamos en**:
`D:\Multinube\cloud\gcp\dbt\cnh_gcp`

---

## 2️⃣ Qué vamos a hacer hoy con dbt (solo estrategia + pasos, sin ahogarnos)

Objetivo de hoy:

> Dejar un **proyecto dbt en GCP funcionando**, apuntado a tu proyecto `da-port-cnh-dev`, con estructura Bronze/Silver/Gold lista y al menos **1 modelo Bronze** compilando contra BigQuery.

### Paso 1 – Crear carpeta para dbt en GCP

1. En el explorador:

   * Ir a `D:\Multinube\cloud\gcp\`
   * Crear carpeta nueva: `dbt`
2. Dentro de `dbt`, crear una carpeta vacía:

   * `cnh_gcp`  (pero **no metas nada a mano todavía**, la llenará `dbt init`).

Ruta final de trabajo de hoy:
`D:\Multinube\cloud\gcp\dbt\cnh_gcp`

---

### Paso 2 – Crear entorno Python para dbt

En PowerShell (o CMD), parado en la carpeta `dbt`:

```powershell
cd D:\Multinube\cloud\gcp\dbt

# 1) Crear entorno virtual
python -m venv .venv

# 2) Activarlo
.\.venv\Scripts\activate

# 3) Instalar dbt para BigQuery
pip install dbt-core dbt-bigquery
```

Con eso ya tienes el “motor dbt” listo en tu máquina.

---

### Paso 3 – Inicializar el proyecto dbt

Desde la misma consola (con el venv activo):

```powershell
dbt init cnh_gcp
```

Cuando te pregunte:

* **Nombre del proyecto:** `cnh_gcp` (el que ya le pusimos).
* **Adaptador:** elige **bigquery**.
* Te pedirá datos del profile, pero no te preocupes: lo afinamos en el siguiente paso.

Eso te va a crear dentro de `D:\Multinube\cloud\gcp\dbt\cnh_gcp` algo así:

```text
cnh_gcp/
  dbt_project.yml
  models/
    example/
  macros/
  tests/
  ...
```

Luego borraremos la carpeta `example/` para dejar solo lo nuestro.

---

### Paso 4 – Conectar dbt a BigQuery (profiles.yml)

dbt usa un archivo `profiles.yml` que vive en:

```text
C:\Users\<TU_USUARIO>\.dbt\profiles.yml
```

Lo que necesitamos es crear/editar ese archivo con un **profile para BigQuery**, por ejemplo:

```yaml
cnh_gcp:               # Debe coincidir con 'profile:' en dbt_project.yml
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth           # Usando tu sesión de gcloud / navegador
      project: da-port-cnh-dev
      dataset: cnh_bronze     # dataset por defecto donde dbt creará tablas
      location: US
      threads: 4
      timeout_seconds: 300
      priority: interactive
      retries: 1
```

Con eso le estás diciendo:

* Usa **BigQuery**.
* Conéctate al proyecto `da-port-cnh-dev`.
* Crea las tablas por defecto en el dataset `cnh_bronze` (que ya planeamos para Bronze).

> Si mañana queremos que Silver vaya a otro dataset (`cnh_silver`), lo manejaremos con **configuración por modelo**, no cambiando el profile.

---

### Paso 5 – Limpiar modelos de ejemplo y crear estructura Bronze/Silver/Gold

Dentro de `cnh_gcp\models\`:

1. Borra la carpeta `example/`.
2. Crea esta estructura:

```text
models/
  cnh/
    staging/        ← solo definiciones de SOURCES (tablas externas)
    bronze/
    silver/
    gold/
```

Y también un archivo `models/cnh/_schema.yml` (o uno por carpeta) donde más adelante:

* Declararemos los **sources** (las tablas externas de `cnh_staging`).
* Documentaremos columnas.
* Definiremos tests sencillos (`not_null`, `unique`, etc.).

Hoy solo dejaremos creado el archivo vacío o con un pequeño esqueleto.

---

### Paso 6 – Conectar Staging como “source” (conceptual, sin código denso todavía)

La idea estratégica (no el detalle de YAML todavía) es:

* Declarar en dbt algo como:

  * `source.name = cnh_staging`
  * `tables = oil_production_ext`, `gas_production_ext`

Para que en los modelos Bronze podamos escribir:

```sql
select * 
from {{ source('cnh_staging', 'oil_production_ext') }}
```

En vez de poner el nombre completo de BigQuery a mano.
Eso hace tu ETL **portátil y gobernado por contrato**.

---

### Paso 7 – Primer modelo Bronze (mañana lo llenamos a detalle)

Estrategia para el primer modelo:

* Archivo: `models/cnh/bronze/oil_production_bz.sql`
* Tipo: **table** materialized en `cnh_bronze`.
* Lógica alineada al contrato Bronze:

  * CAST de tipos (`fecha` a DATE, métricas a FLOAT64).
  * Renombrar columnas si hace falta.
  * **NO** filtrar (`WHERE`).
  * **NO** COALESCE de nulos.
  * Solo tipado y estructura.

Mañana sí escribimos el SQL completo y corremos:

```powershell
dbt run -m oil_production_bz
```

---

## 3️⃣ Resumen para hoy (checklist)

Para que no se sienta pesado, el “combo” de hoy viernes es:

* [ ] Crear carpetas `D:\Multinube\cloud\gcp\dbt\cnh_gcp`
* [ ] Crear y activar entorno `.venv` + instalar `dbt-core dbt-bigquery`
* [ ] Ejecutar `dbt init cnh_gcp`
* [ ] Configurar `profiles.yml` apuntando a `da-port-cnh-dev` y `cnh_bronze`
* [ ] Organizar `models/cnh/{staging,bronze,silver,gold}`
* [ ] Dejar preparado un esqueleto para **sources** y **modelo Bronze** (sin meternos aún a todas las reglas de negocio)

Con esto, cuando entremos al siguiente bloque, ya podemos:

* Escribir el SQL Bronze respetando el contrato.
* Correr `dbt run`.
* Ver las tablas creadas en BigQuery, pero ahora **bajo gobierno dbt**, no sueltas.

Ejecutar:

gcloud auth application-default login


5️⃣ Activar el venv de dbt:

cd D:\Multinube\cloud\gcp\dbt
.\.venv\Scripts\activate
cd cnh_gcp


6️⃣ Ejecutar:

dbt debug

