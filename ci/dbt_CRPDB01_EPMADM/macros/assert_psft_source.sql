{#
    Stops a model that reads PeopleSoft through CI_PSFT_SOURCE while that
    source cannot be what the Informatica mapping read. Called at the top of the
    model body, so it runs at compile time - before any hook - and neither a
    TRUNCATE nor a MERGE is ever sent.

      1. The source is the target. The validated scripts name every PeopleSoft
         read in EPMADM, and for tables that also exist as EPMADM targets
         (PS_Z_JTP_RELATE_CI, PS_Z_PMRG_*_TBL, PS_Z_*_GEN_STAT) that makes the
         load read its own target: a truncate-and-reload empties it, a MERGE
         brings in nothing new.

    Repointing CI_PSFT_SOURCE in models/epmadm_schema.yml at the replicated
    PeopleSoft schema clears it, with no model change.

    It compares configuration only and never queries the database. Snowflake
    compiles the whole project when `snow dbt deploy` creates the dbt project
    object - with the profile's default target, dev - so a compile-time check
    that depends on what exists fails the deploy itself. This macro's former
    must_exist check did exactly that to CI on 2026-09-12, because
    PS_Z_CPP_DTL_VW does not exist. The truncate-and-reload models now read one
    row of their source in a pre-hook ahead of the TRUNCATE instead; see
    PS_Z_JTP_RELATE_CI and PS_Z_CPP_D00.

    CI_PSFT_SOURCE now points at BRONZE_CORP_CONF.BRONZE_PEOPLESOFT, so the
    check passes on every target; it stays to catch a source that is repointed
    back into EPMADM. On the ci target it only logs a warning, because there
    every source that follows target.database lands in the one CI schema.
#}
{% macro assert_psft_source(src, tgt) %}

    {% if execute %}

        {% if (src.database | upper, src.schema | upper, src.identifier | upper)
           == (tgt.database | upper, tgt.schema | upper, tgt.identifier | upper) %}
            {% if target.name == 'ci' %}
                {{ log("WARNING " ~ model.name ~ ": its PeopleSoft source " ~ src ~ " is its own target"
                       ~ " in the CI database. Building anyway so CI can validate the project.", info=True) }}
            {% else %}
                {{ exceptions.raise_compiler_error(
                    model.name ~ ": its PeopleSoft source " ~ src ~ " is its own target " ~ tgt ~ "."
                    ~ " Point source CI_PSFT_SOURCE at the replicated PeopleSoft schema in"
                    ~ " models/epmadm_schema.yml."
                ) }}
            {% endif %}
        {% endif %}

    {% endif %}

{% endmacro %}
