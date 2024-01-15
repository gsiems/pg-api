
CREATE OR REPLACE FUNCTION plprofiler_client.save_collect_data ()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;
    PERFORM pl_profiler_collect_data ( ) ;

END ;
$function$;
