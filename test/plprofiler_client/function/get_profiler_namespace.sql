
CREATE OR REPLACE FUNCTION plprofiler_client.get_profiler_namespace ()
RETURNS record
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
-- Find out the namespace of the plprofiler extension.

    l_schema_name text ;
    l_error text ;
    r record ;
    l_version integer ;
    l_version_string text ;

BEGIN

    l_schema_name := plprofiler_client.query_plprofiler_namespace()::text ;

    IF l_schema_name IS NOT NULL THEN

        EXECUTE format ( 'SELECT %s.pl_profiler_version(), %s.pl_profiler_versionstr()', l_schema_name, l_schema_name )
            INTO l_version, l_version_string ;

        IF l_version < 40100 or l_version >= 50000 THEN
            l_error := format ( 'ERROR: plprofiler extension is version %s, need 4.x', l_version_string ) ;
        END IF ;

    ELSE
        l_error := format ( 'ERROR: plprofiler extension not found in database %s', pg_catalog.current_database () ) ;
    END IF ;

    RETURN ( l_schema_name, l_error ) ;

EXCEPTION
    WHEN others THEN
        RETURN ( null::text, 'ERROR: cannot determine the version of the plprofiler extension - please upgrade the database extension to 4.1 or higher.' ) ;

END ;
$function$;
