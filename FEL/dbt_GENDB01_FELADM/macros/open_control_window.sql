{#
    JOB_NAME uses model.name, the dbt model name, which is what
    seeds/FEL_JOB_CONTROL_SEEDS.csv holds and what mark_failed_jobs keys on.

    The reference project writes model_name.name here. That is equivalent:
    a macro called inside config() is evaluated at parse time, before the
    model's alias config is applied, so this.name is the model name there
    too. model.name just says so without depending on when the hook renders.
#}
{% macro open_control_window(model_name, autosys_job_name) %}
    {% set app_name= var('app_name_by_schema').get(model.config.schema | upper) %}

    {% set exec_table = model.database ~ '.METADATA.' ~ app_name ~ '_JOB_CONTROL'%}

    {%- if target.name == 'ci' -%}
    SELECT 1
    {%- else -%}
    UPDATE {{exec_table}}
        SET END_DATE             = CURRENT_TIMESTAMP(),
            ROW_UPDATE_TIMESTAMP = CURRENT_TIMESTAMP()
        WHERE JOB_NAME = '{{ model.name }}'
        AND AUTOSYS_JOB_NAME = '{{autosys_job_name}}';
    {%- endif -%}

{% endmacro %}