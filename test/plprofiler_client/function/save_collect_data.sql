CREATE OR REPLACE FUNCTION plprofiler_client.save_collect_data ()
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function save_collect_data

Extracted from plprofiler.py save_collect_data()
*/
BEGIN

    perform plprofiler_client.set_search_path () ;
    perform pl_profiler_collect_data () ;

END ;
$$ ;
