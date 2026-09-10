{#
    Opens a JOB_EXECUTION row for the model.

    Divergences from dp-cust-cxnext:

      1. SOURCE_OBJECT and TARGET_OBJECT are filled in here rather than left
         NULL, so a row that never reaches log_model_end - because the model
         failed and mark_failed_jobs marked it FAILED - still records what the
         model was reading and what it was writing.
      2. A promotion guard. Every model already calls this macro, so it is the
         one place that can stop an unfinished conversion reaching a real
         environment. See assert_ready_for_promotion below.

    SOURCE_OBJECT emits a literal {{ this }} rather than the model_name
    argument. A macro called inside config() runs at PARSE time, before the
    model's own alias config is applied, so the argument is the un-aliased
    relation - the target table for every aliased model here. Emitting the
    literal makes dbt render it later, with the alias in effect. See the note
    in log_model_end.sql for the measurements behind this.

    target_object is optional and defaults to the model's own relation, which
    is correct for a model that materialises its target directly. Models whose
    hooks write a different table pass that table's name.
#}
{% macro log_model_start(model_name, autosys_job_name, target_object=none) %}

    {# stop the run if not provided #}
    {% if not autosys_job_name or (autosys_job_name | trim) == '' %}
        {{ exceptions.raise_compiler_error(
            "Missing required autosys_job_name for this model"
        ) }}
    {% endif %}

    {{ assert_ready_for_promotion(autosys_job_name) }}

    {# app_name for table name (from folder +vars fallback) #}
    {% set app_name = var('app_name_by_schema').get(model.config.schema | upper) %}

    {% if app_name is none %}
        {{ exceptions.raise_compiler_error(
            "Missing required app_name for schema: " ~ model.config.schema
        ) }}
    {% endif %}

    {% set exec_table = model.database ~ '.METADATA.' ~ app_name ~ '_JOB_EXECUTION' %}
    {% set tgt = target_object if target_object else model_name %}

    insert into {{ exec_table }} (
        JOB_NAME,
        AUTOSYS_JOB_NAME,
        JOB_STATUS,
        START_TIMESTAMP,
        END_TIMESTAMP,
        ROW_CREATE_TIMESTAMP,
        ROW_UPDATE_TIMESTAMP,
        SOURCE_OBJECT,
        TARGET_OBJECT,
        RECORDS_PROCESSED,
        ERROR_MESSAGE
        )

    values (
        '{{ model.name }}',
        '{{ autosys_job_name }}',
        'STARTED',
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        NULL,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        '{% raw %}{{ this }}{% endraw %}',
        '{{ tgt }}',
        NULL,
        NULL);

{% endmacro %}


{#
    Refuses to compile a model that is not finished, on the targets where an
    unfinished model does damage.

    Two things reach production silently if nothing checks for them:

      A frozen load window. Informatica resolves $$START_TIME / $$END_TIME from
      the parameter file at runtime; the conversion captures one run, so the
      resolved literal is what lands in the SQL. Validation then passes because
      it compares against that same run - the frozen value is exactly what makes
      the comparison succeed. In production the model re-reads one fixed slice
      for ever. Nothing errors: these models carry anti-joins, so re-reading the
      same window produces no duplicates and no row-count anomaly. The table
      just stops advancing.

      A placeholder Autosys job name. TBD_* names still write JOB_EXECUTION rows,
      so the run looks audited while the control row can never be matched by
      the scheduler.

    dev and ci are left alone: building with frozen literals is exactly what you
    want while converting and validating. qa, uat and prod refuse to compile.

    The README lists what is still open for each model.
#}
{% macro assert_ready_for_promotion(autosys_job_name) %}

    {% if execute and target.name in ('qa', 'uat', 'prod') %}

        {% set sql = model.get('raw_code', model.get('raw_sql', '')) %}

        {% if modules.re.search("TO_TIMESTAMP_NTZ\\s*\\(\\s*'\\d", sql) %}
            {{ exceptions.raise_compiler_error(
                model.name ~ ": a frozen date literal is still in the model body."
                ~ " Move it onto the JOB_CONTROL run window before promoting to "
                ~ target.name ~ ". The README lists the models this applies to."
            ) }}
        {% endif %}

        {% if (autosys_job_name | string).startswith('TBD') %}
            {{ exceptions.raise_compiler_error(
                model.name ~ ": placeholder autosys_job_name '" ~ autosys_job_name
                ~ "'. Set the real Autosys job name in log_model_start and"
                ~ " log_model_end - log_model_end matches on it, so the two must"
                ~ " agree or the STARTED row is never closed."
            ) }}
        {% endif %}

    {% endif %}

{% endmacro %}
