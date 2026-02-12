# **✅ Estructura enterprise recomendada (probada en proyectos reales)**

Dentro de cada repo (GCP y control-plane):

```
docs/
│
├── adr/                     # Architecture Decision Records
│   ├── ADR-0001-repo-layout.md
│   ├── ADR-0002-bronze-philosophy.md
│   └── ADR-0003-claim-commit.md
│
├── checkpoints/             # cierres formales
│   ├── 2026-02-11-bronze-closed.md
│   └── 2026-02-12-github-ready.md
│
├── runbooks/                # cómo operar el sistema
│   ├── run-dbt-local.md
│   ├── replay-files.md
│   └── rebuild-silver.md
│
├── troubleshooting/        # problemas reales
│   ├── bigquery-merge-issues.md
│   ├── object-table-permissions.md
│
├── technical-notes/        # explicaciones profundas
│   ├── manifest-design.md
│   ├── surrogate-keys.md
│
├── debt/                   # deuda técnica consciente
│   └── DEBT-0001-no-ci-cd-yet.md
│
├── queries/                # SQL importantes
│   ├── validation-bronze.sql
│   └── audit-manifest.sql
│
└── assets/                 # logos, diagramas
    ├── dtq_logo.png
    └── architecture.png
```

Esto es exactamente lo que usan equipos serios.

---

# **🧱 Qué va en cada uno**

## **📐 adr/**

Decisiones irreversibles:

Ejemplo:

Por qué usamos claim/commit  
Por qué Bronze acepta basura  
Por qué surrogate keys SHA256

Formato:

```
ADR-000X-title.md
```

---

## **📍 checkpoints/**

“Hoy cerramos Bronze.”

Esto es histórico.

---

## **🏃 runbooks/**

Manual operativo:

* cómo correr dbt  
* cómo reprocesar archivos  
* cómo validar Silver

Esto es para otro ingeniero.

---

## **🧯 troubleshooting/**

Errores reales:

* qué pasó  
* síntoma  
* causa  
* solución

---

## **🧠 technical-notes/**

Explicaciones profundas:

* arquitectura  
* patrones  
* decisiones

---

## **⚠️ debt/**

Deuda explícita:

Esto es brutalmente profesional.

Ejemplo:

```
DEBT-0002-no-terraform.md
```

---

## **🔍 queries/**

SQL útiles que no son modelos.

Auditoría, validación, debugging.

---

# **🔑 Regla de oro**

No escribas “bonito”.

Escribe:

* claro  
* técnico  
* reproducible

---

