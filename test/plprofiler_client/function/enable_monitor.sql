CREATE OR REPLACE FUNCTION plprofiler_client.enable_monitor (
    a_opt_pid integer DEFAULT NULL::integer,
    a_opt_interval integer DEFAULT 10 )
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function enable_monitor turns monitoring on

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_opt_pid                      | in     | integer    | The PID of the backend to monitor                  |
| a_opt_interval                 | in     | integer    | Interval in seconds at which the monitored backend(s) will copy the local-data to shared-data and then reset their local-data. |

Extracted from plprofiler.py enable_monitor()
*/
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

                RAISE EXCEPTION 'ERROR: monitor command not supported on server version %s. Perform monitoring manually via postgresql.conf changes and reloading the postmaster.',
                    r2.setting ;

            END LOOP ;

        END IF ;

    END LOOP ;

    perform plprofiler_client.set_search_path () ;

    IF a_opt_pid IS NOT NULL THEN
        perform pl_profiler_set_enabled_pid ( a_opt_pid ) ;
    ELSE
        perform pl_profiler_set_enabled_global ( true ) ;
    END IF ;

    perform pl_profiler_set_collect_interval ( coalesce ( a_opt_interval, 10 ) ) ;

END ;
$$ ;
