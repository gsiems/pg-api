CREATE OR REPLACE PROCEDURE util_log.log_begin (
    variadic a_args text[] )
LANGUAGE plpgsql
AS $$
/**
Procedure log_begin is used to log the beginning of a function/procedure

If the function/procedure is called from another function/procedure then this
is logged as "Begin" level, otherwise this is logged as "Entry" level.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_args                         | in     | text[]     | The list of elements to log                        |

To log the calling parameters for a plpgsql function/procedure, simply add a
call to log_begin at the top of the function/procedure:

```
BEGIN
    call util_log.log_begin (
        util_log.dici ( parameter_one ),
        util_log.dici ( parameter_two ),
        ...
        util_log.dici ( parameter_n ) ) ;
    ...
```

*/
BEGIN
    call util_log.log_to_dblink ( 30, variadic a_args ) ;
END ;
$$ ;
