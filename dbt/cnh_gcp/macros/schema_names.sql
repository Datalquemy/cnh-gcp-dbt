{% macro generate_schema_name(custom_schema_name, node) -%}
  {# 
    Si el modelo NO define +schema, usa el schema del target (del profile).
    Si el modelo SÍ define +schema, usa SOLO ese (sin prefijos).
  #}
  {%- if custom_schema_name is none -%}
    {{ target.schema }}
  {%- else -%}
    {{ custom_schema_name | trim }}
  {%- endif -%}
{%- endmacro %}
