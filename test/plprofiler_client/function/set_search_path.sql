
CREATE OR REPLACE FUNCTION plprofiler_client.set_search_path ()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN

    PERFORM set_config ( 'search_path', concat_ws ( ', ', plprofiler_client.query_plprofiler_namespace ( ), 'pg_catalog' ), true ) ; --true ??

END ;
$function$;
