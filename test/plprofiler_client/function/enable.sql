
CREATE OR REPLACE FUNCTION plprofiler_client.enable ()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;
    PERFORM pl_profiler_set_enabled_local ( true ) ;
    PERFORM pl_profiler_set_collect_interval ( 0 ) ;

END ;
$function$;
