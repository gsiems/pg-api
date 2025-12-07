| [Home](../readme.md) | [API](readme.md) | util_meta |

## Index<a name="top"></a>

 * Function [mk_api_procedure](#function-mk_api_procedure) returns text
 * Function [mk_can_do_function_shell](#function-mk_can_do_function_shell) returns text
 * Function [mk_find_function](#function-mk_find_function) returns text
 * Function [mk_get_function](#function-mk_get_function) returns text
 * Function [mk_json_function_wrapper](#function-mk_json_function_wrapper) returns text
 * Function [mk_json_user_type](#function-mk_json_user_type) returns text
 * Function [mk_json_view](#function-mk_json_view) returns text
 * Function [mk_list_children_function](#function-mk_list_children_function) returns text
 * Function [mk_list_function](#function-mk_list_function) returns text
 * Function [mk_object_migration](#function-mk_object_migration) returns text
 * Function [mk_priv_delete_procedure](#function-mk_priv_delete_procedure) returns text
 * Function [mk_priv_insert_procedure](#function-mk_priv_insert_procedure) returns text
 * Function [mk_priv_update_procedure](#function-mk_priv_update_procedure) returns text
 * Function [mk_priv_upsert_procedure](#function-mk_priv_upsert_procedure) returns text
 * Function [mk_resolve_id_function](#function-mk_resolve_id_function) returns text
 * Function [mk_user_type](#function-mk_user_type) returns text
 * Function [mk_view](#function-mk_view) returns text

[top](#top)
## Function [mk_api_procedure](../../schema/util_meta/function/mk_api_procedure.sql)
Returns text

Function mk_api_procedure generates a draft API procedure for a DML action on a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_action                       | in     | text       | The action that the generated procedure should perform {insert, update, upsert, delete} |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the procedure |

Generates the API code that checks permissions and wraps the appropriate
"private" procedure that does the actual work.

ASSERTIONS:

1. The table to create the procedure for has a single, integer, primary key column
2. The associated private procedure has already been created in the database


[top](#top)
## Function [mk_can_do_function_shell](../../schema/util_meta/function/mk_can_do_function_shell.sql)
Returns text

Function mk_can_do_function_shell generates the shell of a draft can_do function

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |


[top](#top)
## Function [mk_find_function](../../schema/util_meta/function/mk_find_function.sql)
Returns text

Function mk_find_function generates a draft "find matching entries" function for a table.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_is_row_based                 | in     | boolean    | Indicates if the permissions model is row-based (default is table based) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

ASSERTIONS

 * There is a view for the table (mk_view) being selected from, either in the
 DDL schema or in a corresponding "private" schema.


[top](#top)
## Function [mk_get_function](../../schema/util_meta/function/mk_get_function.sql)
Returns text

Function mk_get_function generates a draft get item function for a table.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

ASSERTIONS

 * There is a view for the table (mk_view) being selected from, either in the
 DDL schema or in a corresponding "private" schema.

 * In the schema that the get function will be created in there will be a
 function for resolving the ID of the table (mk_resolve_id_function)


[top](#top)
## Function [mk_json_function_wrapper](../../schema/util_meta/function/mk_json_function_wrapper.sql)
Returns text

Function mk_json_function_wrapper generates a draft JSON wrapper around a
regular set returning function ( find_, get_, list_ )

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the regular function |
| a_object_name                  | in     | text       | The (name of the) name of the regular function     |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the json function in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the json function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted on the json function |

Note that JSON objects schema defaults to the concatenation of a_object_schema with '_json'

ASSERTIONS

 * The function being wrapped uses a view as the return type


[top](#top)
## Function [mk_json_user_type](../../schema/util_meta/function/mk_json_user_type.sql)
Returns text

Function mk_json_user_type generates a user type for a table or view with lowerCamelCase column names

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to create a user type from |
| a_object_name                  | in     | text       | The (name of the) table/view to create a user type from |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the type in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the type |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted select on the view |


[top](#top)
## Function [mk_json_view](../../schema/util_meta/function/mk_json_view.sql)
Returns text

Function mk_json_view generates a draft view of a table in JSON format

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to wrap with the json view |
| a_object_name                  | in     | text       | The (name of the) table/view to wrap with the JSON view |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the JSON view in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the JSON view |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted on the JSON view |

Note that this should work for dv_, rv_, and sv_ views

Note that JSON objects schema defaults to the concatenation of a_object_schema with '_json'


[top](#top)
## Function [mk_list_children_function](../../schema/util_meta/function/mk_list_children_function.sql)
Returns text

Function mk_list_children_function generates a draft "list entries that are children of the specified parent" function for a table.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_parent_table_schema          | in     | text       | The (name of the) schema that contains the parent table   |
| a_parent_table_name            | in     | text       | The (name of the) parent table                     |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_exclude_binary_data          | in     | boolean    | Indicates if binary (bytea, jsonb) data is to be excluded from the result-set (default is to include binary data) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

If the parent table is not specified then the function will attempt to determine a parent

ASSERTIONS

 * There is a view for the table (mk_view) being selected from, either in the
 DDL schema or in a corresponding "private" schema.

 * In the schema that the get function will be created in there will be a
 function for resolving the ID of the parent table (mk_resolve_id_function)

 * If the parent table is not specified then there is only one parent data table

TODO

 * Explore the feasibility of implementing the query for row-based permissions
 (currently uses permissions for parent table tow)


[top](#top)
## Function [mk_list_function](../../schema/util_meta/function/mk_list_function.sql)
Returns text

Function mk_list_function generates a draft "list entries" function for a table.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_exclude_binary_data          | in     | boolean    | Indicates if binary (bytea, jsonb) data is to be excluded from the result-set (default is to include binary data) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

ASSERTIONS

 * There is a view for the table (mk_view) being selected from, either in the
 DDL schema or in a corresponding "private" schema.

TODO

 * Explore the feasibility of implementing the query for row-based permissions


[top](#top)
## Function [mk_object_migration](../../schema/util_meta/function/mk_object_migration.sql)
Returns text

Function mk_object_migration generates a script for migrating the structure of a table, or any other database object

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the object to migrate |
| a_object_name                  | in     | text       | The (name of the) object to create a migration script for |


[top](#top)
## Function [mk_priv_delete_procedure](../../schema/util_meta/function/mk_priv_delete_procedure.sql)
Returns text

Function mk_priv_delete_procedure generates a draft "private" delete procedure for a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |

Note that this should work for dt and rt table types

Note that the generated procedure has no permissions check and is not intended
to be called from outside the database


[top](#top)
## Function [mk_priv_insert_procedure](../../schema/util_meta/function/mk_priv_insert_procedure.sql)
Returns text

Function mk_priv_insert_procedure generates a draft "private" insert procedure for a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |

Note that this should work for dt and rt table types

Note that the generated procedure has no permissions check and is not intended
to be called from outside the database


[top](#top)
## Function [mk_priv_update_procedure](../../schema/util_meta/function/mk_priv_update_procedure.sql)
Returns text

Function mk_priv_update_procedure generates a draft "private" update procedure for a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |

Note that this should work for dt and rt table types

Note that the generated procedure has no permissions check and is not intended
to be called from outside the database


[top](#top)
## Function [mk_priv_upsert_procedure](../../schema/util_meta/function/mk_priv_upsert_procedure.sql)
Returns text

Function mk_priv_upsert_procedure generates a draft "private" upsert procedure for a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |

Note that this should work for dt and rt table types

Note that the generated procedure has no permissions check and is not intended
to be called from outside the database


[top](#top)
## Function [mk_resolve_id_function](../../schema/util_meta/function/mk_resolve_id_function.sql)
Returns text

Function mk_resolve_id_function generates a draft function for resolving reference table IDs

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

The goal is to create a function that allows the user to supply either the ID or natural key for a reference
data table and have the function resolve and return the appropriate ID.

ASSERTIONS:

 * Reference tables have single-column synthetic primary keys

 * Reference tables have single-column natural keys (multi-column natural keys will require tweaking of the generated function)

 * The natural key for the reference table follows the table_name + '_nk' convention

Note that this should work for all rt_ and st_ tables


[top](#top)
## Function [mk_user_type](../../schema/util_meta/function/mk_user_type.sql)
Returns text

Function mk_user_type generates a user defined type for a table or view

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to create a user type from |
| a_object_name                  | in     | text       | The (name of the) table/view to create a user type from |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the type in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the type |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted privs on the type |


[top](#top)
## Function [mk_view](../../schema/util_meta/function/mk_view.sql)
Returns text

Function mk_view generates a draft view of a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the view for     |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the view in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the view  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted select on the view |

The goal is to combine the table columns of the specified table with the
natural key columns of any referenced tables to create a draft view.

This does not (currently) attempt to recurse beyond the parent tables for the
specified table (parents of parents).

Aspirational goal: to recurse parent reference tables.

Aspirational goal: to recognize self-referential tables and add the recursive
CTE for all parent records.

Note that this should work for all table types (dt, rt, st)

