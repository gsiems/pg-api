
CREATE OR REPLACE FUNCTION plprofiler_client.reset_local ()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;
    PERFORM pl_profiler_reset_local ( ) ;

END ;
$function$;
