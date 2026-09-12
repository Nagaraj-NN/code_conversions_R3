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

      2. must_exist=true: the source does not exist. Used by the
         truncate-and-reload models, where the TRUNCATE pre-hook would otherwise
         empty the target before the read failed.

    Repointing CI_PSFT_SOURCE in models/epmadm_schema.yml at the replicated
    PeopleSoft schema clears both, with no model change.

    CI_PSFT_SOURCE now points at BRONZE_CORP_CONF.BRONZE_PEOPLESOFT, so check 1
    passes on every target; it stays to catch a source that is repointed back
    into EPMADM. On the ci target it only logs a warning, because there every
    source that follows target.database lands in the one CI schema. Check 2
    stays fatal on every target: a missing source fails the build anyway, and
    this fails it before the TRUNCATE.
#}
{% macro assert_psft_source(src, tgt, must_exist=false) %}

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

        {% if must_exist and adapter.get_relation(database=src.database, schema=src.schema, identifier=src.identifier) is none %}
            {{ exceptions.raise_compiler_error(
                model.name ~ ": its source " ~ src ~ " does not exist. The TRUNCATE pre-hook would"
                ~ " empty " ~ tgt ~ " before the load failed, so the model stops here."
            ) }}
        {% endif %}

    {% endif %}

{% endmacro %}
