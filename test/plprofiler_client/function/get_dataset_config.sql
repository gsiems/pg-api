CREATE OR REPLACE FUNCTION plprofiler_client.get_dataset_config (
    a_opt_name text )
RETURNS plprofiler_client.ut_config
LANGUAGE plpgsql
AS $$
/**
Function get_dataset_config returns the config for the specified profile as JSON.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_opt_name                     | in     | text       | The name of the saved-dataset to get a config for  |

Extracted from plprofiler.py get_dataset_config()
*/
DECLARE

    r record ;

BEGIN

    perform plprofiler_client.set_search_path () ;

    FOR r IN (
        SELECT s_options
            FROM pl_profiler_saved
            WHERE s_name = a_opt_name ) LOOP

        RETURN json_to_config ( r.s_options::json ) ;

    END LOOP ;

    RAISE EXCEPTION 'No saved data with name ''%s'' found', a_opt_name ;

    RETURN NULL::plprofiler_client.ut_config ;

END ;
$$ ;
