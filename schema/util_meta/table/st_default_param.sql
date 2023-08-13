CREATE TABLE util_meta.st_default_param (
    id smallint NOT NULL,
    name text,
    description text,
    allowed_values text,
    default_value text,
    CONSTRAINT st_default_param_pk PRIMARY KEY ( id ),
    CONSTRAINT st_default_param_nk UNIQUE ( name ) ) ;

COMMENT ON TABLE util_meta.st_default_param IS 'Calling parameters that may have (optional) default configuration values.' ;

COMMENT ON COLUMN util_meta.st_default_param.id IS 'The primary key.' ;
COMMENT ON COLUMN util_meta.st_default_param.name IS 'The name of the configuration parameter.' ;
COMMENT ON COLUMN util_meta.st_default_param.description IS 'The description of the configuration parameter.' ;
COMMENT ON COLUMN util_meta.st_default_param.allowed_values IS 'The csv list of allowed values (as applicable).' ;
COMMENT ON COLUMN util_meta.st_default_param.default_value IS 'The default value (as applicable).' ;

WITH n AS (
    SELECT id,
            name,
            description
        FROM (
            VALUES
                ( 1, 'a_owner', 'The default role to grant ownership of the generated database object to.' ),
                ( 2, 'a_update_object_type', 'The default object type to generate for insert, update, upsert, and delete functionality.' ),
                ( 3, 'a_cast_booleans_as', 'The csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values).' ),
                ( 4, 'a_insert_audit_columns', 'The csv list of insert audit columns (user created, timestamp created, etc.) that the database (client) user doesn''t directly edit.' ),
                ( 5, 'a_update_audit_columns', 'The csv list of update audit columns (user updated, timestamp last updated, etc.) that the database (client) user doesn''t directly edit.' )
            ) AS dat (id, name, description )
),
missing AS (
    SELECT n.id,
            n.name,
            n.description
        FROM n
        LEFT JOIN util_meta.st_default_param o
            ON ( o.id = n.id )
        WHERE o.id IS NULL
)
INSERT INTO util_meta.st_default_param (
        id,
        name,
        description )
    SELECT id,
            name,
            description
        FROM missing ;

UPDATE util_meta.st_default_param
    SET allowed_values = 'function,procedure',
        default_value = 'function'
    WHERE name = 'update_object_type' ;


/* Other potential options:

'a_json_casing', 'The type of attribute casing to use for emitting/ingesting JSON.'

UPDATE util_meta.st_default_param
    SET allowed_values = 'snake,lowerCamel,upperCamel',
        default_value = 'lowerCamel'
    WHERE name = 'a_json_casing' ;

----

'api_schema', 'The schema to create standard API objects in.'
'json_api_schema', 'The schema to create JSON API objects in.'

a_test_schema

*/

/*

| a_action                       | in     | text       | The data management action that the procedure should perform {insert, update, upsert} |
| a_action                       | in     | text       | The (name of the) action that that is to be performed |
| a_assertions                   | in     | text[]     | The list of assertions made by the function/procedure |
| a_assertions                   | in     | text[]     | The list of assertions made by the procedure       |
| a_audit_columns                | in     | text       | The (optional) csv list of audit columns (user created, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_cast_booleans_as             | in     | text       | The (optional) csv list of "true,false" values to cast booleans as (if booleans are to be cast) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_check_result                 | in     | boolean    | Indicates if there should be a check of the return value |
| a_comment                      | in     | text       | The text of the comment for the object             |
| a_comments                     | in     | text[]     | The list of the comments for the parameters        |
| a_datatypes                    | in     | text[]     | The list of the datatypes for the parameters       |
| a_ddl_schema                   | in     | text       | The (name of the) module (and hence schema) to create the function in (if different from the table schema) |
| a_ddl_schema                   | in     | text       | The (name of the) schema of the object being commented on |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the json function in |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the JSON view in |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the object in   |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the type in (if different from the table schema) |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the view in (if different from the table schema) |
| a_ddl_schema                   | in     | text       | The (name of the) schema where whatever function/procedure is being created in |
| a_directions                   | in     | text[]     | The list of the calling parameter directions       |
| a_exclude_binary_data          | in     | boolean    | Indicates if binary (bytea, jsonb) data is to be excluded from the result-set (default is to include binary data) |
| a_exclude_columns              | in     | text       | The (optional)(csv list of) column names to exclude from the json object |
| a_function_name                | in     | text       | The (name of the) function  to create              |
| a_function_name                | in     | text       | The (name of the) kind of ID resolution function   |
| a_function_schema              | in     | text       | The (name of the) schema to find the function in   |
| a_grantees                     | in     | text       | The csv list of roles that should be granted execute on the function |
| a_grantees                     | in     | text       | The csv list of roles that should be granted execute on the procedure |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted on the json function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted on the JSON view |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted select on the view |
| a_identifier                   | in     | text       | The identifier to transform                        |
| a_id_param                     | in     | text       | The (name of the) parameter to set the resolved ID to  |
| a_id_param                     | in     | text       | The parameter to use for the id argument           |
| a_indents                      | in     | integer    | The number of indentations to prepend to each line of the code snippet (default 0) |
| a_indents                      | in     | integer    | The number of indentations to prepend to each line of the code snippet (default 1) |
| a_indents                      | in     | integer    | The (optional) number of indents to add to the code snippet (default 0) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_is_row_based                 | in     | boolean    | Indicates if the permissions model is row-based (default is table based) |
| a_language                     | in     | text       | The language that the function is written in (defaults to plpgsql) |
| a_language                     | in     | text       | The language that the procedure is written in (defaults to plpgsql) |
| a_local_var_datatypes          | in     | text[]     | The list of the datatypes for the local variables  |
| a_local_var_names              | in     | text[]     | The list of local variable names                   |
| a_notes                        | in     | text[]     | The list of notes for the user/developer of the function |
| a_object_name                  | in     | text       | The name of the database object                    |
| a_object_name                  | in     | text       | The (name of the) name of the regular function     |
| a_object_name                  | in     | text       | The (name of the) object being commented on        |
| a_object_name                  | in     | text       | The (name of the) object to check the existence of |
| a_object_name                  | in     | text       | The (name of the) object to create                 |
| a_object_name                  | in     | text       | The (name of the) procedure to wrap                |
| a_object_name                  | in     | text       | The (name of the) table                            |
| a_object_name                  | in     | text       | The (name of the) table to create a migration script for |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure parameter list for |
| a_object_name                  | in     | text       | The (name of the) table to create the view for     |
| a_object_name                  | in     | text       | The (name of the) table/view to create a user type from |
| a_object_name                  | in     | text       | The (name of the) table/view to wrap with the JSON view |
| a_object_purpose               | in     | text       | The (brief) description of the purpose of the object |
| a_object_schema                | in     | text       | The (name of the) schema that contains the object  |
| a_object_schema                | in     | text       | The (name of the) schema that contains the procedure to wrap |
| a_object_schema                | in     | text       | The (name of the) schema that contains the regular function |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table to migrate |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to create a user type from |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to wrap with the json view |
| a_object_type                  | in     | text       | The (name of the) kind of object to perform the permissions check for |
| a_object_type                  | in     | text       | The (name of the) object type                      |
| a_object_type                  | in     | text       | The (name of the) type of object to check the existence of |
| a_object_type                  | in     | text       | The type {function, procedure} of the object       |
| a_object_type                  | in     | text       | The type of object to create                       |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the json function |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the JSON view |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the type |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the view  |
| a_owner                        | in     | text       | The role that is to be the owner of the function   |
| a_owner                        | in     | text       | The role that is to be the owner of the procedure  |
| a_param_comments               | in     | text[]     | The list of the comments for the parameters        |
| a_param_datatypes              | in     | text[]     | The list of the datatypes for the parameters       |
| a_param_directions             | in     | text[]     | The list of the calling parameter directions       |
| a_param_names                  | in     | text[]     | The list of calling parameter names                |
| a_param_types                  | in     | text[]     | The (optional) list of calling parameter data types |
| a_parent_id_param              | in     | text       | The parameter to use for the parent id argument    |
| a_parent_object_type           | in     | text       | The (name of) the type of object that is the parent of the object to check permissons for (think inserts) |
| a_parent_table_name            | in     | text       | The (name of the) parent table                     |
| a_parent_table_schema          | in     | text       | The (name of the) schema that contains the parent table   |
| a_procedure_name               | in     | text       | The (name of the) procedure to create              |
| a_procedure_purpose            | in     | text       | The (brief) description of the purpose of the procedure |
| a_resolve_id_params            | in     | text[]     | The list of parameters for the ID resolution function |
| a_returns_set                  | in     | text       | Indicates if the return type is a set (vs. scalar) (defaults to scalar) |
| a_return_type                  | in     | text       | The data type to return                            |
| a_test_schema                  | in     | text       | The (name of the) schema to create the wrapper function in |
| a_text                         | in     | text       | The text to clean up                               |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_user_id_param                | in     | text       | The parameter to check the user Id for (default a_user) |
| a_user_id_var                  | in     | text       | The name of the user ID variable to populate (default l_acting_user_id) |
| a_var_datatypes           | in     | text[]     | The list of the datatypes for the variables        |
| a_var_names               | in     | text[]     | The list of variable names                         |
| a_where_columns                | in     | text       | The (csv list of) column names to filter and group by |
| a_where_columns                | in     | text       | The (optional) (csv list of) column names to filter by |
| a_word                         | in     | text       | The word to transform                              |


*/
