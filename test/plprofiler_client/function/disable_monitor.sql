
CREATE OR REPLACE FUNCTION plprofiler_client.disable_monitor ()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;
    PERFORM pl_profiler_set_enabled_global ( false ) ;
    PERFORM pl_profiler_set_enabled_pid ( 0 ) ;
    PERFORM pl_profiler_set_collect_interval ( 0 ) ;

END ;
$function$;
