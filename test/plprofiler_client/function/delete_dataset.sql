
CREATE OR REPLACE FUNCTION plprofiler_client.delete_dataset (
    a_opt_name text )
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE

    l_row_count bigint ;

BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;

    DELETE FROM pl_profiler_saved
        WHERE s_name = a_opt_name ;

    GET DIAGNOSTICS l_row_count = ROW_COUNT ;

    IF l_row_count != 1 THEN
        RAISE EXCEPTION 'Data set with name ''%s'' does not exist', a_opt_name ;
    END IF ;

END ;
$function$;
