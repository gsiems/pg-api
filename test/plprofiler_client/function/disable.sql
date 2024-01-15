
CREATE OR REPLACE FUNCTION plprofiler_client.disable ()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;
    PERFORM pl_profiler_set_enabled_local ( false ) ;

END ;
$function$;
