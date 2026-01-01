CREATE OR REPLACE FUNCTION plprofiler_client.query_plprofiler_namespace ()
RETURNS name
LANGUAGE SQL
STABLE
AS $$
/**
Function query_plprofiler_namespace returns the schema name used by the
plprofiler extension.

Extracted from plprofiler.py get_profiler_namespace()
*/
SELECT n.nspname
    FROM pg_catalog.pg_extension e
    JOIN pg_catalog.pg_namespace n
        ON n.oid = e.extnamespace
    WHERE e.extname = 'plprofiler' ;
$$ ;
