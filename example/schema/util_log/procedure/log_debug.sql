CREATE OR REPLACE PROCEDURE util_log.log_debug (
    variadic a_args text[] )
LANGUAGE plpgsql
AS $$
/**
Procedure log_info is used to log the "Debug" level information.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_args                         | in     | text[]     | The list of debug elements to log                  |

*/
BEGIN
    call util_log.log_to_dblink ( 50, variadic a_args ) ;
END ;
$$ ;
