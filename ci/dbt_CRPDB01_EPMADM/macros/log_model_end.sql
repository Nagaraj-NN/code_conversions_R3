{#
    Closes the JOB_EXECUTION row for the model.

    Divergences from dp-cust-cxnext:

      1. RECORDS_PROCESSED is filled in. The count comes from the model's own
         relation, counted in a FROM subquery rather than a SET subquery
         because Snowflake's UPDATE ... SET does not take a scalar subquery.
         What the number means depends on the model's shape - see below.
      2. SOURCE_OBJECT / TARGET_OBJECT are (re)stated, so the completed row is
         self-describing even if log_model_start was changed later.
      3. app_name is guarded, the same way log_model_start guards it. Without
         the guard a missing mapping silently builds the table name
         "<DB>.METADATA.None_JOB_EXECUTION".

    WHEN THINGS GET RENDERED - why the {% raw %} below is needed.

    A macro called inside config() is evaluated at PARSE time and its output is
    stored as the hook text. At that point the model's own `alias` config has
    not been applied, so a `this` passed in as an argument is the UN-ALIASED
    relation. Measured on dbt 1.10.15 / dbt-snowflake 1.10.8, model MY_MODEL
    with alias MY_MODEL_SRC:

        pre_hook=[ my_macro(this) ]        ->  CRPDB01.EPMADM.MY_MODEL
        macro emits a literal {{ this }}   ->  CRPDB01.EPMADM.MY_MODEL_SRC
        pre_hook=[ "... {{ this }} ..." ]  ->  CRPDB01.EPMADM.MY_MODEL_SRC

    So the `model_name` argument is the un-aliased relation, which for every
    aliased model here is the TARGET table rather than the model's own. A count
    taken from it would report the size of the target instead of the rows this
    model produced. RECORDS_PROCESSED and SOURCE_OBJECT therefore emit a literal
    {{ this }} for dbt to render later, when the alias is in effect.

    JOB_NAME uses model.name, the dbt model name. At parse time this.name
    happens to equal it, so the reference project's `model_name.name` yields the
    same value and is correct; model.name states it explicitly and stays right
    whenever the hook is rendered. It must match the r.node.name that
    mark_failed_jobs keys on, and it does.

    What RECORDS_PROCESSED counts, by model shape:

      truncate + reload      the model IS the target, so this is rows loaded.
      table + INSERT/UPDATE  the model is the transformed source row set, so
        post-hooks            this is ROWS READ - the Informatica reader count
                              (BLKR_16019), not rows applied. Rows applied per
                              branch would need RESULT_SCAN on each hook, which
                              is fragile; compare rows read first.
      delete post-hook       the model holds one row per target row removed, so
                              this is rows deleted.

    Pass `records` to override the expression when a model needs a different
    definition.
#}
{% macro log_model_end(model_name, autosys_job_name, target_object=none, records=none) %}

    {% set app_name = var('app_name_by_schema').get(model.config.schema | upper) %}

    {% if app_name is none %}
        {{ exceptions.raise_compiler_error(
            "Missing required app_name for schema: " ~ model.config.schema
        ) }}
    {% endif %}

    {% set exec_table = model.database ~ '.METADATA.' ~ app_name ~ '_JOB_EXECUTION' %}
    {% set tgt = target_object if target_object else model_name %}

    update {{ exec_table }} E
    set
        JOB_STATUS = 'COMPLETED',
        END_TIMESTAMP = current_timestamp()::timestamp_ntz,
        ROW_UPDATE_TIMESTAMP = current_timestamp()::timestamp_ntz,
        SOURCE_OBJECT = '{% raw %}{{ this }}{% endraw %}',
        TARGET_OBJECT = '{{ tgt }}',
        RECORDS_PROCESSED = C.N
    from ( {% if records %}{{ records }}{% else %}SELECT COUNT(*) AS N FROM {% raw %}{{ this }}{% endraw %}{% endif %} ) C
    WHERE
        E.job_name = '{{ model.name }}'
        AND E.autosys_job_name = '{{ autosys_job_name }}'
        AND E.job_status = 'STARTED'
        AND E.END_TIMESTAMP IS NULL;

{% endmacro %}
