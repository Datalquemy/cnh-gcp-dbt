## ---

**🛡️ Checkpoint: Resolución de Integridad en Capa Silver**

### **1\. El Diagnóstico (El "Bug" Semántico)**

Detectamos que el sistema no estaba deduplicando los registros del campo **ALONDRA** (teníamos hasta 4 versiones: PEMEX, IA OIL, IA GAS y DTQ), a pesar de que la intención era que "el último ganara".

**¿Por qué pasaba?**

Había un divorcio en la lógica del modelo SQL:

* **La Llave Única:** Ya habíamos quitado el operador de la fórmula del Hash (SHA256). El sistema sabía que la "identidad" era solo la fecha \+ campo.  
* **El Deduplicador (Dedupe):** El ROW\_NUMBER() seguía teniendo el operador en el PARTITION BY.  
* **Consecuencia:** El sistema creaba un "Ranking 1" para cada operador diferente. Al final, el WHERE rn \= 1 dejaba pasar a todos porque cada uno era "el mejor de su propia categoría".

### ---

**2\. Decisiones Tomadas (The "Golden Rules")**

Tomamos tres decisiones críticas para robustecer el pipeline:

* **Unificación de Criterios:** Se eliminó el operador del PARTITION BY en la función de ventana. Ahora, el ranking se calcula estrictamente por anio, mes, cuenca, ubicacion, campo.  
* **Primacía del Timestamp:** Se ratificó que el criterio de desempate es \_ingestion\_timestamp\_utc DESC. Esto garantiza que, ante cualquier error de dedo o cambio manual, el archivo cargado más recientemente es la **Verdad Absoluta**.  
* **Separación de Identidad vs. Atributos:**  
  * **Identidad (Fija):** Fecha y Campo.  
  * **Atributo (Variable):** Operador. (El operador ahora puede cambiar sin crear registros duplicados).

### ---

**3\. Resultado Esperado (Estado Final)**

Con estos cambios aplicados en el código:

1. **Silver:** Al leer Bronze, encontrará los 4 registros de Alondra, pero solo el de **DTQ Energy** recibirá el rn \= 1\. Los demás serán descartados automáticamente.  
2. **Unificada:** Recibirá solo una fila de Aceite y una de Gas, ambas con el nombre **DTQ Energy**. El JOIN será perfecto (1 a 1).  
3. **Idempotencia:** Puedes volver a correr el proceso mil veces y el resultado siempre será la foto más reciente y limpia.

### ---

**💡 Insight para el RedTeam**

"El pipeline fue diseñado para ser **auto-correctivo**. No requiere limpieza manual de la capa Bronze ante errores humanos (typos en operadores); la capa Silver actúa como un filtro de gobernanza que resuelve conflictos de identidad basándose en el linaje temporal de la ingesta."

