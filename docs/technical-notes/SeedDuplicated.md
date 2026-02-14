# **Checkpoint — 2026-feb-14**

# **Resolución de duplicados en seed \+ ejecución selectiva de dbt tests**

## **Contexto**

Durante la validación del seed cat\_campos\_cnh, se detectaron fallos en tests unique y not\_null sobre la columna campo.

El objetivo era:

* Identificar duplicados reales

* Limpiar el CSV

* Rehacer el seed

* Ejecutar únicamente los tests asociados al seed

* Evitar disparar todo Silver/Gold

---

## **1️⃣ Detección de duplicados directamente en BigQuery**

Primero se validó si el problema era real en la tabla cargada:

SELECT  
  campo,  
  COUNT(\*) AS cnt  
FROM \`project.dataset.cat\_campos\_cnh\`  
GROUP BY campo  
HAVING cnt \> 1  
ORDER BY cnt DESC;

Esto confirmó:

* Existían valores duplicados en campo

* dbt estaba fallando correctamente

También se usó este query para inspección visual:

SELECT \*  
FROM \`project.dataset.cat\_campos\_cnh\`  
WHERE campo IN (  
  SELECT campo  
  FROM \`project.dataset.cat\_campos\_cnh\`  
  GROUP BY campo  
  HAVING COUNT(\*) \> 1  
)  
ORDER BY campo;

---

## **2️⃣ Limpieza del CSV en Excel**

Se limpió el CSV directamente en Excel usando una sola fórmula para normalizar texto:

### **Fórmula (Excel español):**

\=ESPACIOS(LIMPIAR(A2))

Esto:

* Elimina espacios dobles

* Quita tabs invisibles

* Remueve caracteres raros

* Normaliza valores aparentemente iguales

Luego:

* Se copiaron valores

* Pegado especial → valores

---

## **3️⃣ Reseed completo del archivo**

Después de limpiar el CSV:

dbt seed \--full-refresh

Esto:

* Borra la tabla del seed

* La vuelve a crear desde cero

* Relee el CSV limpio

---

## **4️⃣ Problema:** 

## **dbt test**

##  **ejecutaba TODO**

Al correr:

dbt test

dbt ejecutaba:

* Silver

* Gold

* Todos los tests históricos

Esto NO era deseado.

---

## **5️⃣ Intento de seleccionar solo el seed (fallido inicialmente)**

Se intentó:

dbt test \--select seed:cat\_campos\_cnh

Resultado:

The selection criterion 'seed.cat\_campos\_cnh' does not match any enabled nodes

Aquí estaba el problema:

👉 dbt no usa el nombre del CSV

👉 usa el resource name interno

---

## **6️⃣ Descubrimiento del nombre real usando** 

## **dbt ls**

Se ejecutó:

dbt ls \--resource-type seed

Resultado:

cnh\_gcp.cat\_campos\_cnh

Ese es el selector correcto.

---

## **7️⃣ Ejecución correcta del test del seed**

Finalmente:

dbt test \--select cnh\_gcp.cat\_campos\_cnh

Resultado:

PASS unique\_cat\_campos\_cnh\_campo  
PASS not\_null\_cat\_campos\_cnh\_campo

Solo se ejecutaron:

* unique

* not\_null

sobre el seed.

Nada más.

---

## **Conclusiones técnicas**

### **✅ Esto NO fue workaround**

Fue:

* Data validation en BigQuery

* Data cleansing upstream

* Full reseed controlado

* Uso correcto de dbt selectors

* Ejecución quirúrgica de tests

Patrón aplicado:

Detect → Clean → Reseed → Select → Test

Esto es Analytics Engineering real.

---

## **Lecciones clave**

### **dbt seeds usan nombre interno:**

package.seed\_name

NO el CSV directo.

Siempre verificar con:

dbt ls \--resource-type seed

---

### **Nunca usar** 

### **dbt test**

###  **a ciegas**

Siempre usar selectores:

dbt test \--select ...

---

### **Duplicados en seeds \= problema de fuente, no de dbt**

dbt solo expone el error.

---

## **Comandos finales resumidos**

\# Ver nombre real del seed  
dbt ls \--resource-type seed

\# Reseed completo  
dbt seed \--full-refresh

\# Test solo del seed  
dbt test \--select cnh\_gcp.cat\_campos\_cnh

