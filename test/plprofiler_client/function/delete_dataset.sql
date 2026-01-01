CREATE OR REPLACE FUNCTION plprofiler_client.delete_dataset (
    a_opt_name text )
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function delete_dataset deletes the named saved-dataset

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_opt_name                     | in     | text       | The name of the saved-dataset to delete            |

Extracted from plprofiler.py delete_dataset()
*/
DECLARE

    l_row_count bigint ;

BEGIN

    perform plprofiler_client.set_search_path () ;

    DELETE FROM pl_profiler_saved
        WHERE s_name = a_opt_name ;

    GET diagnostics l_row_count = row_count ;

    IF l_row_count != 1 THEN
        RAISE EXCEPTION 'Data set with name ''%s'' does not exist', a_opt_name ;
    END IF ;

END ;
$$ ;
