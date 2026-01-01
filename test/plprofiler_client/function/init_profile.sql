CREATE OR REPLACE FUNCTION plprofiler_client.init_profile (
    a_name text )
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function init_profile

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_name                         | in     | text       | The name of the saved-dataset                      |

*/
BEGIN

    perform plprofiler_client.set_search_path () ;
    perform plprofiler_client.disable_monitor () ;
    DELETE FROM pl_profiler_saved
        WHERE s_name = a_name ;

    perform plprofiler_client.enable_monitor () ;

END ;
$$ ;
