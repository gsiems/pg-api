CREATE OR REPLACE FUNCTION util_meta._uses_logging ()
RETURNS boolean
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _uses_logging checks if the database has the util_log schema

*/

SELECT EXISTS (
            SELECT 1
                FROM pg_catalog.pg_proc p
                JOIN pg_catalog.pg_namespace n
                    ON ( n.oid = p.pronamespace )
                WHERE n.nspname::text = 'util_log'
                    AND p.proname::text = 'log_begin' ) ;

$$ ;
