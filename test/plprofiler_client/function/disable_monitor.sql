CREATE OR REPLACE FUNCTION plprofiler_client.disable_monitor ()
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function disable_monitor turns monitoring off

Extracted from plprofiler.py disable_monitor()
*/
BEGIN

    perform plprofiler_client.set_search_path () ;
    perform pl_profiler_set_enabled_global ( false ) ;
    perform pl_profiler_set_enabled_pid ( 0 ) ;
    perform pl_profiler_set_collect_interval ( 0 ) ;

END ;
$$ ;
