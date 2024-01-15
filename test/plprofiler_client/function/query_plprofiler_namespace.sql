
CREATE OR REPLACE FUNCTION plprofiler_client.query_plprofiler_namespace ()
RETURNS name
LANGUAGE sql
STABLE
AS $function$
    SELECT n.nspname
        FROM pg_catalog.pg_extension e
        JOIN pg_catalog.pg_namespace n
            ON n.oid = e.extnamespace
        WHERE e.extname = 'plprofiler' ;
$function$;
