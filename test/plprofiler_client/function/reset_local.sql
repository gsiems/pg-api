CREATE OR REPLACE FUNCTION plprofiler_client.reset_local ()
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function reset_local

Extracted from plprofiler.py reset_local()
*/
BEGIN

    perform plprofiler_client.set_search_path () ;
    perform pl_profiler_reset_local () ;

END ;
$$ ;
