{% macro generate_database_name(custom_database_name, node) %}
    {% if target.name == 'ci' %}
        TEST_DBT_DB
    {% else %}
        {{ custom_database_name if custom_database_name else target.database }}
    {% endif %}
{% endmacro %}

{% macro generate_schema_name(custom_schema_name, node) %}
    {% if target.name == 'ci' %}
        {{ var('ci_schema') }}
    {% else %}
        {{ custom_schema_name if custom_schema_name else target.schema }}
    {% endif %}
{% endmacro %} 