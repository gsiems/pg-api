CREATE OR REPLACE FUNCTION plprofiler_client.get_dataset_list ()
RETURNS TABLE (
    s_name text,
    s_options text )
LANGUAGE plpgsql
AS $$
/**
Function get_dataset_list returns the configs for all stored profiles.

Extracted from plprofiler.py get_dataset_list()
*/
BEGIN

    perform plprofiler_client.set_search_path () ;

    RETURN QUERY
    SELECT s_name,
            s_options
        FROM pl_profiler_saved
        ORDER BY s_name ;

END ;
$$ ;
