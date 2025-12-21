CREATE OR REPLACE PROCEDURE util_log.log_exception (
    variadic a_args text[] )
LANGUAGE plpgsql
AS $$
/**
Procedure log_info is used to log the "Exception" level information.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_args                         | in     | text[]     | The list of exception elements to log              |

To log an exception:

```
    call util_log.log_exception ( SQLSTATE::text || ' - ' || SQLERRM ) ;
```

*/
BEGIN
    call util_log.log_to_dblink ( 10, variadic a_args ) ;
END ;
$$ ;
