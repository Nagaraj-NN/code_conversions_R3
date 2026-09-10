{% macro mark_failed_jobs(results) %}

  {{ log("mark_failed_jobs macro started", info=True) }}

  {% for r in results %}

    {{ log("Checking model: " ~ r.node.name ~ " | status: " ~ r.status, info=True) }}

    {% if r.node.resource_type == 'model' and r.status != 'success' %}

      {{ log("Failed model detected: " ~ r.node.name, info=True) }}

      {% set model_name = r.node.name %}
      {% set db = r.node.database %}
      {% set schema = r.node.schema %}

      {# Get app_name from mapping #}
      {% set app_name = var('app_name_by_schema').get(schema | upper) %}

      {{ log("DB=" ~ db ~ ", SCHEMA=" ~ schema ~ ", APP_NAME=" ~ app_name, info=True) }}

      {# Safety check #}
      {% if app_name is none %}
        {{ exceptions.raise_compiler_error("app_name mapping missing for schema: " ~ schema) }}
      {% endif %}

      {# Build execution table name #}
      {% set exec_table = db ~ '.METADATA.' ~ app_name ~ '_JOB_EXECUTION' %}

      {{ log("Execution Table: " ~ exec_table, info=True) }}

      {# Clean error message #}
      {% set err = (r.message or '') | replace("'", "''") %}

      {# Build update SQL #}
      {% set sql %}
        update {{ exec_table }}
        set
          job_status = 'FAILED',
          end_timestamp = current_timestamp(),
          row_update_timestamp = current_timestamp(),
          error_message = '{{ err[:500] }}'
        where
          job_name = '{{ model_name }}'
          and job_status = 'STARTED'
          and end_timestamp is null;
      {% endset %}

      {{ log("Executing SQL: " ~ sql, info=True) }}

      {% do run_query(sql) %}

    {% endif %}

  {% endfor %}

{% endmacro %}