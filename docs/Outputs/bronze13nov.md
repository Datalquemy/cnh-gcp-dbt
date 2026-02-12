Perfecto ⚙️
Aquí tienes el **plan estratégico de trabajo para mañana 13 de noviembre de 2025**, diseñado para avanzar desde la capa *staging* (ya lista) hacia la **Fase Bronze** del pipeline GCP CNH ETL, con base en el checkpoint anterior.

---

# 🧭 PLAN DE TRABAJO — JUEVES 13 DE NOVIEMBRE 2025

**Proyecto:** CNH ETL – GCP
**Autor:** Dr. Emmanuel Pérez Cabrera (DatAlquemy)
**Fase:** Bronze (Transformación estructural y tipado)
**Duración estimada:** 4 a 5 horas
**Modo de ejecución:** Manual (consola BigQuery + notas en bitácora técnica)

---

## 🎯 Objetivo del día

Construir la **Capa Bronze** del Data Lakehouse en BigQuery, asegurando:

* Integridad estructural (tipos correctos, sin truncamientos).
* Preservación completa de la historia (sin filtrado por valores).
* Base sólida para aplicar las reglas de negocio en Silver.

---

## 🧩 1. Preparación inicial

**1.1 Crear el dataset `cnh_bronze`**

* Ubicación: misma región del proyecto (`US` o `us-central1`).
* Propósito: alojar las tablas físicas (no externas) que representarán la versión *tipada* de staging.
* Descripción recomendada:

  > Dataset de transformación estructural (Bronze) — limpieza de tipos, sin reglas de negocio.

---

## ⚙️ 2. Creación de las tablas Bronze

**2.1. Tablas objetivo:**

* `cnh_bronze.oil_production_bz`
* `cnh_bronze.gas_production_bz`

**2.2. Estructura esperada (schema tipado):**

| Columna        | Tipo    | Descripción                                          |
| -------------- | ------- | ---------------------------------------------------- |
| fecha          | DATE    | Fecha de producción                                  |
| cuenca         | STRING  | Región o cuenca petrolera                            |
| ubicacion      | STRING  | Terrestre o Marina                                   |
| campo          | STRING  | Campo de extracción                                  |
| operador       | STRING  | Compañía operadora                                   |
| liquidos_mbd   | FLOAT64 | Producción de líquidos (miles de barriles diarios)   |
| petroleo_mbd   | FLOAT64 | Producción de petróleo (miles de barriles diarios)   |
| condensado_mbd | FLOAT64 | Producción de condensado (miles de barriles diarios) |

> En el caso de **gas_production**, se usan las métricas:
> `gas_natural_sin_nitrogeno_mmpcd` y `nitrogeno_mmpcd` (FLOAT64).

---

## 🧱 3. Lógica de carga (Staging → Bronze)

**Estrategia:**
Usar consultas SQL en BigQuery para seleccionar desde las tablas externas `cnh_staging.*` hacia las tablas físicas `cnh_bronze.*`, aplicando:

* **CAST explícito** de tipos (DATE, FLOAT64).
* **Normalización de nombres** (sin espacios, todo en minúsculas).
* **Preservación total de nulos y ceros.**
* **Sin filtros** (`WHERE valor > 0` queda prohibido en esta etapa).

**Configuración física:**

* **Partición:** `PARTITION BY DATE(fecha)`
* **Clustering:** `CLUSTER BY campo, operador`

Esto mejora rendimiento y costo sin alterar semántica.

---

## 🧠 4. Validaciones estructurales post-creación

1. **Conteo base:**
   Comparar cantidad de registros entre staging y bronze (deben coincidir).

   ```sql
   SELECT COUNT(*) FROM cnh_staging.oil_production_ext;
   SELECT COUNT(*) FROM cnh_bronze.oil_production_bz;
   ```

2. **Verificación de rango temporal:**
   Confirmar que los años más antiguos (1960s) se conservan.

   ```sql
   SELECT MIN(fecha), MAX(fecha) FROM cnh_bronze.oil_production_bz;
   ```

3. **Muestreo visual:**

   ```sql
   SELECT * FROM cnh_bronze.oil_production_bz WHERE fecha < '1975-01-01' LIMIT 10;
   ```

4. **Validar tipos:** revisar desde la pestaña *Esquema* de BigQuery.

---

## 🧾 5. Documentación en Bitácora Técnica

Agregar al archivo `GCP_ETL_PHASE2_BRONZE.md` los siguientes apartados:

* Fecha y hora de creación de las tablas Bronze.
* SQL ejecutado (resumido).
* Screenshot de esquema y conteo de filas.
* Observaciones sobre el rango temporal y valores pequeños.
* Confirmación de que **no se aplicaron filtros ni remplazos de nulos.**

---

## 🚀 6. Entregable esperado al cierre del día

✅ `cnh_bronze` dataset creado
✅ `oil_production_bz` y `gas_production_bz` creadas y particionadas
✅ Validación de conteos y rangos temporales
✅ Documentación base en bitácora

---

## 🧱 7. Avance proyectado para el viernes 14

* Iniciar **Fase Silver**, aplicando reglas de negocio:

  * COALESCE y unificación Oil/Gas.
  * Normalización de operadores y campos.
  * Creación de `cnh_silver.produccion_unificada_sv`.

---

¿Deseas que mañana, además del plan operativo, te deje lista una **plantilla base del archivo `GCP_ETL_PHASE2_BRONZE.md`** (formato bitácora técnica para copiar al GitHub)?
Puedo incluir encabezados, espacios para evidencias y bloques SQL listos para pegar.
