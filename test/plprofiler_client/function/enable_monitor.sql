
CREATE OR REPLACE FUNCTION plprofiler_client.enable_monitor (
    a_opt_pid integer DEFAULT NULL::integer,
    a_opt_interval integer DEFAULT 10)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE

    r record ;
    r2 record ;

BEGIN

    FOR r IN (
        SELECT setting
            FROM pg_catalog.pg_settings
            WHERE name = 'server_version_num' ) LOOP

        IF r.setting::int < 90400 THEN

            FOR r2 IN (
                SELECT setting
                    FROM pg_catalog.pg_settings
                    WHERE name = 'server_version' ) LOOP

                RAISE EXCEPTION 'ERROR: monitor command not supported on server version %s. Perform monitoring manually via postgresql.conf changes and reloading the postmaster.', r2.setting ;

            END LOOP ;

        END IF ;

    END LOOP ;

    PERFORM plprofiler_client.set_search_path ( ) ;

    IF a_opt_pid IS NOT NULL THEN
        PERFORM pl_profiler_set_enabled_pid ( a_opt_pid ) ;
    ELSE
        PERFORM pl_profiler_set_enabled_global ( true ) ;
    END IF ;

    PERFORM pl_profiler_set_collect_interval ( coalesce ( a_opt_interval, 10 ) ) ;

END ;
$function$;
