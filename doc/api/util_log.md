| [Home](../readme.md) | [API](readme.md) | util_log |

## Index<a name="top"></a>

 * Function [dici](#function-dici) returns text
 * Function [manage_partitions](#function-manage_partitions) returns void
 * Function [query_bug](#function-query_bug) returns boolean
 * Function [update_last_logged](#function-update_last_logged) returns bigint
 * Procedure [log_begin](#procedure-log_begin)
 * Procedure [log_debug](#procedure-log_debug)
 * Procedure [log_exception](#procedure-log_exception)
 * Procedure [log_finish](#procedure-log_finish)
 * Procedure [log_info](#procedure-log_info)
 * Procedure [log_to_dblink](#procedure-log_to_dblink)

[top](#top)
## Function [dici](../../schema/util_log/function/dici.sql)
Returns text


Function dici (Italian for "you say") takes an input and converts it to a text output. In the
case of a character/text input it also adds proper quoting.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_arg                          | in     | anyelement | The item to be cast to text.                       |


[top](#top)
## Function [manage_partitions](../../schema/util_log/function/manage_partitions.sql)
Returns void

Procedure manage_partitions creates (and disposes of) table partitions
for the util_log.dt_proc_log table.


[top](#top)
## Function [query_bug](../../schema/util_log/function/query_bug.sql)
Returns boolean


Function query_bug is intended for including in SQL user functions or views to
log if the function/view is being queried from.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_tag                          | in     | text       | The optional tag to log.                           |

NB this is defined as a PLpgSQL (vs. plain SQL) function, possibly because it
needs to be, but primarily to prevent the query optimizer from optimizing it
out of the query.

Queries can be logged using this function by including the function call in the
query definition. This is (potentially) useful for determining if a SQL user
function or view is actually being used.

While simpler,

```
    SELECT t0.
        FROM some_table_name t0
        WHERE ...
            AND util_log.query_bug ( 'optional tag' ) ;
```

appears to result in a logging entry for each tuple selected.

Using a CTE however,

```
    WITH qb AS (
        SELECT util_log.query_bug ( 'optional tag' ) AS x
    )
    SELECT t0.
        FROM some_table_name t0
        CROSS JOIN qb
        WHERE ...
            AND qb.x ;
```

appears to result in only one logging entry for each time the query is executed.


[top](#top)
## Function [update_last_logged](../../schema/util_log/function/update_last_logged.sql)
Returns bigint

Procedure update_last_logged updates the dt_last_logged table with the
functions, procedures, (or maybe even queries) that have been logged since the
last time that the dt_last_logged table was updated.


[top](#top)
## Procedure [log_begin](../../schema/util_log/procedure/log_begin.sql)

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


[top](#top)
## Procedure [log_debug](../../schema/util_log/procedure/log_debug.sql)

Procedure log_info is used to log the "Debug" level information.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_args                         | in     | text[]     | The list of debug elements to log                  |


[top](#top)
## Procedure [log_exception](../../schema/util_log/procedure/log_exception.sql)

Procedure log_info is used to log the "Exception" level information.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_args                         | in     | text[]     | The list of exception elements to log              |

To log an exception:

```
    call util_log.log_exception ( SQLSTATE::text || ' - ' || SQLERRM ) ;
```


[top](#top)
## Procedure [log_finish](../../schema/util_log/procedure/log_finish.sql)

Procedure log_finish is used to log the conclusion of a function/procedure.

Takes no arguments and simply adds an "Info" entry in the log with the text of
"finished".


[top](#top)
## Procedure [log_info](../../schema/util_log/procedure/log_info.sql)

Procedure log_info is used to log the "Info" level information.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_args                         | in     | text[]     | The list of informational elements to log          |


[top](#top)
## Procedure [log_to_dblink](../../schema/util_log/procedure/log_to_dblink.sql)

Function log_to_dblink takes a logging level and a variable list of text values,
determines which function/procedure was called (and which function/procedure
called it (if applicable)) and uses dblink to log the results.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_log_level                    | in     | integer    | The logging level (per st_log_level)               |
| a_args                         | in     | text[]     | The list of elements to log                        |

