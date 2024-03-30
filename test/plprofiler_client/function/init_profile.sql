
CREATE OR REPLACE FUNCTION plprofiler_client.init_profile (
    a_name text )
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;
    PERFORM plprofiler_client.disable_monitor () ;
    DELETE FROM pl_profiler_saved
        WHERE s_name = a_name ;

    PERFORM plprofiler_client.enable_monitor () ;

END ;
$function$;


