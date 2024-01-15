
CREATE OR REPLACE FUNCTION plprofiler_client.reset_shared ()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;
    PERFORM pl_profiler_reset_shared ( ) ;

END ;
$function$;
