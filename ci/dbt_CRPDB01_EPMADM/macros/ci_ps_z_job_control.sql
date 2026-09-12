{#
    Creates and tops up PS_Z_JOB_CONTROL_CI, this application's own copy of
    PeopleSoft's PS_Z_JOB_CONTROL. Called from on-run-start.

    PeopleSoft's job-control table is replicated into
    BRONZE_CORP_CONF.BRONZE_PEOPLESOFT, where it cannot be updated. The
    Informatica workflow opened, read and closed its load windows on that
    table - PS_Z_JOB_CONTROL_UPD_DTTM, the three delete models,
    PS_Z_JOB_CONTROL_UPD_STATUS - and in Snowflake they do the same on this
    copy.

    Unlike dp-corp-ar80's ar80_ps_z_job_control, which CREATE OR REPLACEs its
    copy on every run, this never replaces or overwrites a row: the table is
    created from bronze only when it does not exist, and a JOBID is added only
    when it is not there yet. The windows the models open and close therefore
    carry over from one run to the next, as they did in Informatica.

    Column names are unquoted, as everywhere else this project reads bronze.
#}
{% macro ci_ps_z_job_control() %}

    CREATE TABLE IF NOT EXISTS {{ source('CRPDB01_EPMADM', 'PS_Z_JOB_CONTROL_CI') }} AS
    SELECT JOBID, TABLE_NAME, LAST_RUN_FROM_DTTM, LAST_RUN_TO_DTTM, STATUS
    FROM {{ source('CI_PSFT_SOURCE', 'PS_Z_JOB_CONTROL') }};

    INSERT INTO {{ source('CRPDB01_EPMADM', 'PS_Z_JOB_CONTROL_CI') }}
        (JOBID, TABLE_NAME, LAST_RUN_FROM_DTTM, LAST_RUN_TO_DTTM, STATUS)
    SELECT B.JOBID, B.TABLE_NAME, B.LAST_RUN_FROM_DTTM, B.LAST_RUN_TO_DTTM, B.STATUS
    FROM {{ source('CI_PSFT_SOURCE', 'PS_Z_JOB_CONTROL') }} B
    WHERE NOT EXISTS (
        SELECT 1
        FROM {{ source('CRPDB01_EPMADM', 'PS_Z_JOB_CONTROL_CI') }} C
        WHERE C.JOBID = B.JOBID
    );

{% endmacro %}
