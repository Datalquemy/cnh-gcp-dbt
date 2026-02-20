---

# **🧭 CHECKPOINT — Incidente Silver / Ventana histórica CNH**

Fecha: 18-Feb-2026

Proyecto: CNH Data Pipeline (Bronze → Silver → Gold)

Stack: BigQuery \+ dbt

Modelo afectado: oil\_production\_sv

---

## **🧠 Síntoma inicial**

Durante las validaciones del modelo Silver, se observó que:

* Bronze contenía datos desde 1960\.

* Silver sólo mostraba datos a partir de 2016\.

* Parecía un problema de:

  * lookback window

  * poda automática de particiones por BigQuery

  * o incremental mal configurado.

A primera vista parecía comportamiento del optimizador de BigQuery.

---

## **🔎 Investigación realizada**

Se ejecutaron múltiples queries directos contra Bronze:

### **1️⃣ Conteo histórico por año con rango explícito**

Confirmado:

✅ Bronze sí tiene datos desde 1960\.

---

### **2️⃣ Conteo con filtros de calidad (**

### **\>= 0**

### **)**

Aquí apareció el patrón:

Cuando se aplicaban filtros tipo:

petroleo\_mbd \>= 0  
AND liquidos\_mbd \>= 0  
AND condensado\_mbd \>= 0

👉 el dataset efectivo arrancaba en 2016\.

---

### **3️⃣ Query de diagnóstico por columna**

Se ejecutó conteo de nulos por año, específicamente sobre:

* petroleo\_mbd

* liquidos\_mbd

* condensado\_mbd

Resultado clave:

🧨 La columna condensado\_mbd viene completamente NULL desde 1960 hasta 2015\.

Mientras que petróleo y líquidos sí tienen valores.

---

## **✅ Root Cause (causa real)**

No era BigQuery.

No era dbt.

No era lookback.

👉 Era esto:

### **El modelo Silver estaba filtrando implícitamente todo el histórico porque:**

condensado\_mbd \= NULL antes de 2016

y al exigir:

condensado\_mbd \>= 0

esas filas quedaban automáticamente fuera.

Por eso Silver “empezaba” en 2016\.

---

## **🧩 Confirmación visual**

En el CSV original (Excel):

* Columna condensado\_mbd vacía completamente hasta 2015\.

* A partir de 2016 empieza a poblarse.

Misterio resuelto.

---

# **🛠️ Solución acordada**

Normalizar explícitamente en Silver:

COALESCE(condensado\_mbd, 0\) AS condensado\_mbd

igual que ya se hace con:

* petroleo\_mbd

* liquidos\_mbd

Esto permite:

✅ conservar histórico completo

✅ aplicar reglas \>= 0

✅ mantener lógica de lookback

✅ evitar poda involuntaria

Ya viste que esto existía en la versión vieja del modelo Silver (rama principal).

Ahora se reinstala en la versión actual.

---

# **🚀 Próximo paso operativo**

### **1️⃣ Actualizar** 

### **oil\_production\_sv.sql**

### **:**

COALESCE(condensado\_mbd, 0\) AS condensado\_mbd

en el SELECT principal.

---

### **2️⃣ Ejecutar:**

dbt run \-s oil\_production\_sv \--full-refresh

Motivo:

El incremental ya dejó fuera el histórico.

Necesitamos reconstruir Silver completo una vez.

---

## **⚠️ Sobre tu duda:**

Si ejecuto dbt run silver, ¿borra lo cargado?

### **Respuesta:**

| Comando | Qué pasa |
| ----- | ----- |
| dbt run | Solo incremental |
| dbt run \--full-refresh | DROP \+ CREATE tabla Silver |

Así que:

👉 NO borres tablas manualmente

👉 Usa \--full-refresh para Silver

dbt se encarga.

---

# **🧱 Estado final esperado**

Después del full refresh:

✅ Silver tendrá datos desde 1960

✅ condensados \= 0 antes de 2016

✅ lookback volverá a funcionar correctamente

✅ Gold podrá construirse limpio

✅ contrato queda consistente

