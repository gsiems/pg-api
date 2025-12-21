CREATE OR REPLACE PROCEDURE util_log.log_info (
    variadic a_args text[] )
LANGUAGE plpgsql
AS $$
/**
Procedure log_info is used to log the "Info" level information.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_args                         | in     | text[]     | The list of informational elements to log          |

*/
BEGIN
    call util_log.log_to_dblink ( 40, variadic a_args ) ;
END ;
$$ ;
