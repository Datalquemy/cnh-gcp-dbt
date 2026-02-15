  
\# Checkpoint — 2026-02-15 — Silver Oil/Gas validados \+ schema\_silver alineado

\#\# Contexto  
Hoy consolidamos la capa \*\*Silver\*\* para los dos dominios de energía:  
\- \*\*oil\_production\_sv\*\* (petróleo / líquidos / condensado)  
\- \*\*gas\_production\_sv\*\* (gas / nitrógeno)

El objetivo fue dejar ambos modelos listos para operar de forma incremental y con grain mensual consistente, y validar que no existan inconsistencias de llave o de fecha.

\---

\#\# Cambios principales en los modelos Silver (Oil y Gas)

\#\#\# 1\) Normalización y grain mensual  
\- Se normalizan \`campo\` y \`operador\` con \`UPPER(TRIM(...))\`.  
\- Se fuerza el \*\*grain mensual\*\* usando \`month\_start\` (primer día del mes) para asegurar:  
  \- particionado consistente por \`fecha\`  
  \- estabilidad del incremental / watermark  
  \- evitar “días sueltos” dentro del mes

\#\#\# 2\) Watermark incremental con lookback de 24 meses  
\- El filtro incremental procesa \*\*los últimos 24 meses\*\* relativos a la propia tabla destino (\`{{ this }}\`), lo que vuelve el pipeline “autorreparable” ante correcciones tardías.  
\- Se usa un \*\*sentinel date\*\* (fecha centinela) como fallback para el primer run cuando \`MAX(fecha)\` es NULL (tabla vacía o inexistente), evitando que el incremental “se quede sin procesar nada”.

\#\#\# 3\) Enriquecimiento canónico por catálogo (cat\_campos\_cnh)  
\- Se hace \`INNER JOIN\` contra \`cat\_campos\_cnh\` para:  
  \- mantener solo campos “en catálogo”  
  \- canonizar \`cuenca\` y \`ubicacion\`

\#\#\# 4\) Deduplicación determinística  
\- Se deduplica con \`ROW\_NUMBER()\` por la PK lógica mensual:  
  \`(anio, mes, cuenca, ubicacion, campo, operador)\`  
\- Se conserva el registro más reciente por \`\_ingestion\_timestamp\_utc\` y \`\_source\_filename\`.

\#\#\# 5\) Llave determinística (surrogate key)  
\- Se genera \`id\_registro\_unico\` como hash determinístico basado en:  
  \`anio|mes|cuenca|ubicacion|campo|operador\`  
\- (En BigQuery, idealmente se materializa como string en HEX si se usa SHA256 directo).

\---

\#\# Validaciones ejecutadas (BigQuery) — Oil

\#\#\# A) Validar que \`fecha\` siempre sea primer día del mes  
\`\`\`sql  
SELECT \*  
FROM cnh\_silver.oil\_production\_sv  
WHERE EXTRACT(DAY FROM fecha) \!= 1  
LIMIT 10;

✅ Resultado esperado/obtenido: 0 filas.

### **B) Validar que no existan duplicados por id\_registro\_unico**

SELECT  
  id\_registro\_unico,  
  COUNT(\*) AS c  
FROM cnh\_silver.oil\_production\_sv  
GROUP BY 1  
HAVING COUNT(\*) \> 1;

✅ Resultado esperado/obtenido: 0 filas.

### **C) Validar que no existan duplicados por grain lógico mensual**

SELECT  
  anio, mes, cuenca, ubicacion, campo, operador,  
  COUNT(\*) AS c  
FROM cnh\_silver.oil\_production\_sv  
GROUP BY 1,2,3,4,5,6  
HAVING COUNT(\*) \> 1;

✅ Resultado esperado/obtenido: 0 filas.

---

## **Validaciones ejecutadas (BigQuery) — Gas**

### **A) Validar que** 

### **fecha**

###  **siempre sea primer día del mes**

SELECT \*  
FROM cnh\_silver.gas\_production\_sv  
WHERE EXTRACT(DAY FROM fecha) \!= 1  
LIMIT 10;

✅ Resultado esperado/obtenido: 0 filas.

### **B) Validar que no existan duplicados por id\_registro\_unico**

SELECT  
  id\_registro\_unico,  
  COUNT(\*) AS c  
FROM cnh\_silver.gas\_production\_sv  
GROUP BY 1  
HAVING COUNT(\*) \> 1;

✅ Resultado esperado/obtenido: 0 filas.

### **C) Validar que no existan duplicados por grain lógico mensual**

SELECT  
  anio, mes, cuenca, ubicacion, campo, operador,  
  COUNT(\*) AS c  
FROM cnh\_silver.gas\_production\_sv  
GROUP BY 1,2,3,4,5,6  
HAVING COUNT(\*) \> 1;

✅ Resultado esperado/obtenido: 0 filas.

---

## **Alineación de documentación (schema.yml)**

Se alineó schema\_silver.yml para reflejar correctamente las columnas de:

* oil\_production\_sv

* gas\_production\_sv

* y dejar preparado el terreno para produccion\_unificada\_sv (el contrato lo contempla; el schema ya debe contemplarlo también).

Archivo generado/alineado:

* schema\_silver\_aligned.yml (para reemplazar/mergear en el schema final del proyecto)

---

## **Próximos pasos**

1. Ejecutar dbt test para ambos modelos Silver:

   * dbt test \-s oil\_production\_sv

   * dbt test \-s gas\_production\_sv

2. Construir/actualizar el modelo produccion\_unificada\_sv:

   * FULL OUTER JOIN por id\_registro\_unico

   * flags de auditoría (p.ej. has\_oil, has\_gas)

   * auditoría de fuentes (\_source\_filename(s)) y timestamps

3. (Opcional, mañana) Completar/ajustar tests adicionales en el schema\_silver.yml para:

   * unique \+ not\_null en id\_registro\_unico

   * not\_null en dimensiones clave (fecha, campo, operador, etc.)

   * tests de consistencia para el unificado.

