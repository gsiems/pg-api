CREATE OR REPLACE PROCEDURE util_log.log_to_none (
    a_log_level integer,
    variadic a_args text[] )
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
/**
Function log_to_none performs no actual logging whatsoever.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_log_level                    | in     | integer    | The logging level (per st_log_level)               |
| a_args                         | in     | text[]     | The list of elements to log                        |

*/
BEGIN

    NULL ;

END ;
$$ ;
