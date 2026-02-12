# **Informe técnico — Publicación de repos (DatAlive Nexus)**

## **Objetivo**

Separar el trabajo en dos repositorios con patrón enterprise:

1. Execution Plane (Runtime): código ejecutable (dbt CNH en GCP)

2. Control Plane: contratos \+ estándares \+ docs \+ scripts (framework)

---

# **1\) Repo Runtime — cnh-gcp-dbt (Execution Plane)**

## **1.1 Ubicación local final**

D:\\datalive-nexus\\repos\\domain-cnh\\gcp

## **1.2 Qué contiene (scope)**

* dbt project: dbt/cnh\_gcp/

  * models/ (bronze/silver/gold \+ staging)

  * macros/

  * seeds/

  * tests/, snapshots/

  * dbt\_project.yml

  * packages.yml, package-lock.yml

* docs del trabajo (plan/notas/validaciones/presentación)

* NO contiene credenciales ni artefactos runtime

## **1.3 Afinación crítica (Git hygiene)**

Se aplicó .gitignore para excluir:

* dbt artifacts: target/, dbt\_packages/, logs/

* runtime externo: dbt/logs/

* entornos python: .venv/, venv/, \_\_pycache\_\_/, \*.pyc

* editor/OS: .vscode/, Thumbs.db, .DS\_Store

* secretos: \*\*/profiles.yml, \*\*/\*.key, \*\*/\*.pem, \*\*/\*.p12, \*\*/\*secret\*, \*\*/\*credential\*

Nota: cuando se ajustó .gitignore después de un git add ., se limpió el staging de logs con git rm \--cached para asegurar que no entrara basura.

## **1.4 Inicialización y primer commit (local)**

Comandos ejecutados:

cd D:\\datalive-nexus\\repos\\domain-cnh\\gcp  
git init  
git add .  
git commit \-m "init: CNH GCP runtime (dbt bronze/silver/gold \+ seeds \+ docs)"

Resultado:

* root commit: c8a6542

* 32 archivos, \~3121 líneas

* sin logs, sin target, sin dbt\_packages, sin venv

## **1.5 Creación del repo remoto (GitHub)**

* Repo creado en GitHub como:

  * cnh-gcp-dbt

* Configuración:

  * Public

  * Sin README inicial

  * Sin .gitignore inicial

  * Sin licencia

URL:

https://github.com/Datalquemy/cnh-gcp-dbt.git

## **1.6 Push al remoto**

git remote add origin https://github.com/Datalquemy/cnh-gcp-dbt.git  
git push \-u origin master

Salida confirmada:

* push exitoso

* branch master quedó trackeando origin/master

---

# 

# **2\) Repo Control Plane Datalive-control-plane(Contracts \+ Standards)**

## **2.1 Ubicación local final**

D:\\datalive-nexus\\repos\\control-plane

## **2.2 Qué contiene (scope)**

Este repo se definió como la fuente de verdad para:

* contracts/ (reglas y contratos por área)

* docs/ (diagramas, plan maestro, presentaciones)

* scripts/ (python/shell)

Dentro de contracts/ incluye:

* bi/, dq/, metadata/, ml/, orquestation/, rag/

* y el dominio actual:

  * contracts/domains/cnh/

## **2.3 Afinación/ordenamiento de contratos CNH (enterprise layout)**

### **Estado inicial**

Los contratos por capa (bronze/silver/gold) estaban en contracts/lake/ con versiones mezcladas.

### 

### **Estado final aprobado (dominio \+ capa \+ current/versions)**

Se organizó CNH así:

D:\\datalive-nexus\\repos\\control-plane\\contracts\\domains\\cnh  
├── bronze  
│   ├── current  
│   │   └── contract.json  
│   └── versions  
│       ├── bronze\_cnh\_v1.json  
│       ├── bronze\_cnh\_v3.json  
│       └── bronze\_cnh\_v5\_1\_full.json  
├── silver  
│   ├── current  
│   │   └── contract.json  
│   └── versions  
│       ├── silver\_cnh\_v2.json  
│       ├── silver\_cnh\_v3.json  
│       └── silver\_cnh\_v4.json  
└── gold  
    ├── current  
    │   └── contract.json  
    └── versions  
        ├── gold\_cnh\_v2.json  
        └── gold\_cnh\_v3.json

### **Convención cerrada**

* current/contract.json es el puntero estable que consumirán los runners.

* versions/ guarda el histórico para auditoría/diffs/rollback.

* CNH usa un solo contrato para gas \+ aceite (unificado).

## **2.4 Inicialización Git (local)**

cd D:\\datalive-nexus\\repos\\control-plane  
git init

## **2.5 .gitignore del control-plane**

Se aplicó .gitignore para evitar:

* secretos (profiles/keys/pems/p12/credential/secret)

* runtime basura (logs/, target/, dbt\_packages/)

* entornos python (.venv/, etc.)

* .vscode/, Thumbs.db, .DS\_Store

## **2.6 Commit local**

git add .  
git commit \-m "init: datalive control-plane (contracts \+ docs \+ scripts)"

## **2.7 Creación del repo remoto (GitHub)**

Repo creado en GitHub:

* datalive-control-plane

* Public

* sin README inicial / sin .gitignore / sin license

URL:

https://github.com/Datalquemy/datalive-control-plane.git

## **2.8 Push al remoto**

git branch \-M main  
git remote add origin https://github.com/Datalquemy/datalive-control-plane.git  
git push \-u origin main

Salida confirmada:

* push exitoso

* branch main quedó trackeando origin/main

* tamaño \~7.42 MiB (contracts+docs+scripts)

---

# **Resultado final (baseline oficial)**

✅ Separación enterprise

* datalive-control-plane \= Control Plane (contratos/estándares)

* cnh-gcp-dbt \= Execution Plane (runner dbt CNH GCP)

✅ Regla cerrada

* No se mezclan contratos dentro del runtime como fuente de verdad.

* Los runners consumen current/contract.json por capa.

✅ Listo para el siguiente paso

* VS Code workspace con ambos repos

* Integración (sync contracts / CI)

* Ejecución de Silver en GCP (cuando toque)

---

