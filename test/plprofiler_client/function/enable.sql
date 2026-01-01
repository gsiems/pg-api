CREATE OR REPLACE FUNCTION plprofiler_client.enable ()
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function enable turns local profiling on

Extracted from plprofiler.py enable()
*/
BEGIN

    perform plprofiler_client.set_search_path () ;
    perform pl_profiler_set_enabled_local ( true ) ;
    perform pl_profiler_set_collect_interval ( 0 ) ;

END ;
$$ ;
