CREATE OR REPLACE FUNCTION plprofiler_client.disable ()
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function disable turns local profiling off

Extracted from plprofiler.py disable()
*/
BEGIN

    perform plprofiler_client.set_search_path () ;
    perform pl_profiler_set_enabled_local ( false ) ;

END ;
$$ ;
