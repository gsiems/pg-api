CREATE OR REPLACE FUNCTION plprofiler_client.set_search_path ()
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function set_search_path set the search_path to the schema of the plprofiler extension

*/
BEGIN

    perform set_config (
        'search_path',
        concat_ws ( ', ', plprofiler_client.query_plprofiler_namespace (), 'pg_catalog' ),
        true ) ; --true ??

END ;
$$ ;
