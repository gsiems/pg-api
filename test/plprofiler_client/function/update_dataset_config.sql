
CREATE OR REPLACE FUNCTION plprofiler_client.update_dataset_config (
    a_opt_name text DEFAULT NULL::text,
    a_new_name text DEFAULT NULL::text,
    a_config plprofiler_client.ut_config DEFAULT NULL::plprofiler_client.ut_config,
    a_config_json json DEFAULT NULL::json )
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE

    l_options text ;
    l_row_count bigint ;

BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;

    l_options := plprofiler_client.resolve_config_string (
        a_opt_name => a_new_name,
        a_config => a_config,
        a_config_json => a_config_json ) ;

    UPDATE pl_profiler_saved
        SET s_name = a_new_name,
            s_options = l_options
        WHERE s_name = a_opt_name ;

    GET DIAGNOSTICS l_row_count = ROW_COUNT ;

    IF l_row_count != 1 THEN
        RAISE EXCEPTION 'Data set with name ''%s'' no longer exists', a_opt_name ;
    END IF ;

END ;
$function$;
