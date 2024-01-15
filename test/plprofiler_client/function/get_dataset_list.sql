
CREATE OR REPLACE FUNCTION plprofiler_client.get_dataset_list ()
RETURNS TABLE (
    s_name text,
    s_options text )
LANGUAGE plpgsql
AS $function$
DECLARE

    r record ;

BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;

    FOR r IN (
        SELECT s_name,
                s_options
            FROM pl_profiler_saved
            ORDER BY s_name ) LOOP

        RETURN NEXT ;

    END LOOP ;

    RETURN ;

END ;
$function$;
