
---

# 📄 **GCP_ETL_PHASE1_SETUP.md**

## 🧭 **Título del checkpoint**

**Fase 1 — Configuración base del entorno GCP para el proyecto CNH ETL**
📅 *Checkpoint creado el domingo 2 de noviembre de 2025*
👤 *Autor: Dr. Emmanuel Pérez Cabrera (DatAlquemy)*

---

## 🎯 **Objetivo**

Establecer la base técnica y de seguridad para el pipeline **ETL CNH** dentro del ecosistema **Google Cloud Platform (GCP)**, replicando la arquitectura profesional de AWS, pero ejecutada manualmente desde la consola para aprendizaje y comprensión total del entorno.

---

## ✅ **Resumen de avances**

### 1️⃣ Proyecto base creado

* Proyecto: `da-port-cnh-dev`
* Cuenta asociada: `emmanuel.eduardo@datalquemy.com`
* Estado: Activo y bajo plan gratuito
* Facturación: Inicializada sin cargos
* APIs verificadas: Cloud Storage, BigQuery, Dataproc, Logging y Monitoring (todas habilitadas por defecto).

---

### 2️⃣ Data Lake configurado (Cloud Storage)

Bucket principal creado:

```
gs://da-port-cnh-dev
```

**Configuración:**

* Región: `us-central1 (Iowa)`
* Clase de almacenamiento: `Standard`
* Acceso público: *Bloqueado (No público)*
* Eliminación no definitiva: *Habilitada (7 días)*
* Replicación: *No aplicada (single region)*

**Estructura interna:**

```
raw/
bronze/
silver/
gold/
logs/
```

📘 *Esta jerarquía implementa la arquitectura Medallion (Bronze–Silver–Gold) y será base de las transformaciones PySpark o Dataproc.*

---

### 3️⃣ IAM y seguridad

Usuario propietario:

```
emmanuel.eduardo@datalquemy.com
```

Rol: *Propietario / Administrador de organización*

Cuenta de servicio creada por sistema:

```
[ID]-compute@developer.gserviceaccount.com
```

➡️ *No modificada; se conserva para servicios internos.*

---

### 4️⃣ Creación de Service Account dedicada

**Nombre:** `sa-cnh-etl`
**Correo:** `sa-cnh-etl@da-port-cnh-dev.iam.gserviceaccount.com`
**Descripción:** *Service Account para el pipeline ETL del proyecto CNH*
**Estado:** Habilitada ✅

**Roles asignados:**

| Rol (Español)                              | Nombre técnico              | Función principal                       |
| ------------------------------------------ | --------------------------- | --------------------------------------- |
| Administrador de objetos de almacenamiento | `roles/storage.objectAdmin` | Acceso total a objetos del Data Lake    |
| Usuario de BigQuery                        | `roles/bigquery.user`       | Permite crear y consultar datasets      |
| Editor de Dataproc                         | `roles/dataproc.editor`     | Permite ejecutar y administrar jobs ETL |

🕓 *Los permisos pueden tardar hasta 5 minutos en propagarse globalmente.*

---

## 🔜 **Siguiente fase (Fase 2 — Ingesta RAW)**

1. Subir dataset CNH (CSV o Parquet) a `gs://da-port-cnh-dev/raw/`
2. Validar lectura desde BigQuery o Dataproc.
3. Documentar flujo de ingesta inicial (scripts o notas de consola).

---

## 📘 **Notas adicionales**

* GCP ofrece una interfaz más fluida y lógica que AWS o Azure para pipelines de datos.
* El entorno ya cumple con las buenas prácticas de seguridad: *principio de menor privilegio, acceso privado, y jerarquía de almacenamiento*.
* Esta configuración sirve como plantilla para futuros proyectos (por ejemplo, *DataAlive GCP Optimized Edition*).

---

**Checkpoint guardado:** 🕒 *Domingo 2 de noviembre de 2025 — Fase completada con éxito*
**Próxima sesión:** *Viernes 7 de noviembre 2025 — Ingesta RAW y validación ETL.*
