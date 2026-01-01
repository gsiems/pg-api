CREATE OR REPLACE FUNCTION plprofiler_client.reset_shared ()
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function reset_shared

Extracted from plprofiler.py reset_shared()
*/
BEGIN

    perform plprofiler_client.set_search_path () ;
    perform pl_profiler_reset_shared () ;

END ;
$$ ;
