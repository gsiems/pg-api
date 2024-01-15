
CREATE OR REPLACE FUNCTION plprofiler_client.get_dataset_config (
    a_opt_name text )
RETURNS plprofiler_client.ut_config
LANGUAGE plpgsql
AS $function$
DECLARE

    r record ;

BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;

    FOR r IN (
        SELECT s_options
            FROM pl_profiler_saved
            WHERE s_name = a_opt_name ) LOOP

        RETURN json_to_config ( r.s_options::json ) ;

    END LOOP ;

    RAISE EXCEPTION 'No saved data with name ''%s'' found', a_opt_name ;

    RETURN null::plprofiler_client.ut_config ;

END ;
$function$;
