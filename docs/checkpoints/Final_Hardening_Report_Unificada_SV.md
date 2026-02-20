¡Excelente noticia\! Si el modelo terminó en verde, hemos pasado la parte más difícil. Ahora vamos a generar la **evidencia de auditoría** que pidió Red Team para "congelar" formalmente el modelo.

Ejecuta estos 4 bloques de SQL en la consola de BigQuery y guarda los resultados (o toma captura); estos son tus argumentos de defensa:

### **1\. Prueba de Integridad PK (Idempotencia)**

**Objetivo:** Demostrar que no hay duplicados y que la llave id\_registro\_unico es infalible.

SQL

SELECT   
    COUNT(\*) AS total\_filas,  
    COUNT(DISTINCT id\_registro\_unico) AS llaves\_unicas,  
    CASE   
        WHEN COUNT(\*) \= COUNT(DISTINCT id\_registro\_unico) THEN '✅ ÉXITO: SIN DUPLICADOS'   
        ELSE '❌ ERROR: SE DETECTARON DUPLICADOS'   
    END AS validacion\_pk  
FROM \`da\-port\-cnh\-dev.cnh\_silver.produccion\_unificada\_sv\`;

### ---

**2\. Prueba de Cobertura y Casos de Negocio (RICOS y XAXAMANI)**

**Objetivo:** Confirmar que el modelo captura los 3 escenarios (Dual, Solo Oil, Solo Gas).

SQL

\-- Resumen de cobertura  
SELECT   
    has\_oil,   
    has\_gas,   
    COUNT(\*) as total\_filas  
FROM \`da\-port\-cnh\-dev.cnh\_silver.produccion\_unificada\_sv\`  
GROUP BY 1, 2  
ORDER BY 1 DESC, 2 DESC;

\-- Validación específica de campos "testigos"  
SELECT   
    campo,   
    has\_oil,   
    has\_gas,   
    COUNT(\*) as registros\_en\_la\_historia,  
    SUM(petroleo\_mbd) as suma\_petroleo,  
    SUM(gas\_mmpcd) as suma\_gas  
FROM \`da\-port\-cnh\-dev.cnh\_silver.produccion\_unificada\_sv\`  
WHERE campo IN ('RICOS', 'XAXAMANI')  
GROUP BY 1, 2, 3;

* **Defensa:** Si **RICOS** sale con has\_oil \= false, demuestras que el modelo no pierde campos gasíferos puros. Si **XAXAMANI** sale con ambos en true, demuestras la unificación exitosa.

### ---

**3\. Prueba de Linaje y Trazabilidad (Source Filenames)**

**Objetivo:** Validar que sabemos exactamente de qué archivo vino cada pedazo del dato.

SQL

SELECT   
    has\_oil,   
    has\_gas,   
    \_source\_filenames,   
    COUNT(\*) as cantidad\_ejemplos  
FROM \`da\-port\-cnh\-dev.cnh\_silver.produccion\_unificada\_sv\`  
GROUP BY 1, 2, 3  
ORDER BY 1 DESC, 2 DESC  
LIMIT 10;

* **Defensa:** Aquí Red verá el pipe | uniendo las rutas de GCS para registros duales y el prefijo NO\_OIL o NO\_GAS para huérfanos.

### ---

**4\. Prueba de Opción B (Costo Predecible)**

**Objetivo:** Confirmar que el modelo está diseñado para particionar y limitar el escaneo (Eficiencia).

SQL

SELECT   
    MIN(fecha) as fecha\_inicio\_tabla,  
    MAX(fecha) as fecha\_fin\_tabla,  
    \-- Conteo de meses para validar que la historia está ahí pero el incremental es eficiente  
    COUNT(DISTINCT DATE\_TRUNC(fecha, MONTH)) as meses\_totales\_en\_silver  
FROM \`da\-port\-cnh\-dev.cnh\_silver.produccion\_unificada\_sv\`;

* **Defensa:** "Aunque la tabla contiene la historia desde 1960 (gracias al full-refresh inicial), el código dbt tiene el filtro WHERE fecha \>= DATE\_SUB(CURRENT\_DATE(), INTERVAL 24 MONTH) activo para todas las cargas incrementales futuras, garantizando que el escaneo de particiones sea siempre controlado".

### ---

**🧊 ¿Cómo declarar el "Freeze"?**

Una vez que estos queries te den los resultados esperados (especialmente que el COUNT sea igual al DISTINCT), puedes decirle a Red Team:

"Blue Team confirma: **Criterios de aceptación cumplidos.** \> 1\. PK íntegra al 100%.

2\. Cobertura validada con casos reales (**RICOS** y **XAXAMANI**).

3\. Linaje transparente en \_source\_filenames.

4\. Opción B implementada para control de costos.

**La versión v1.1 queda oficialmente congelada.**"

¿Qué te arrojó el query de la PK? Si ese sale igual, ¡ya lo tienes\!