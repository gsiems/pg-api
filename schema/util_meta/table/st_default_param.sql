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
                ( 2, 'a_plpgsql_type', 'The default type of PL/pgSQL code (function,procedure) to generate for insert, update, upsert, and delete functionality.' ),
                ( 3, 'a_cast_booleans_as', 'The csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values).' ),
                ( 4, 'a_insert_audit_columns', 'The csv list of insert audit columns (user created, timestamp created, etc.) that the database (client) user doesn''t directly edit.' ),
                ( 5, 'a_update_audit_columns', 'The csv list of update audit columns (user updated, timestamp last updated, etc.) that the database (client) user doesn''t directly edit.' ),
                ( 6, 'indent_char', 'The character(s) to use when adding indentation to code lines.' ),
                ( 7, 'json_casing', 'The type of attribute casing to use for emitting/ingesting JSON.' )
            ) AS dat ( id, name, description )
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
    WHERE name = 'a_plpgsql_type' ;

UPDATE util_meta.st_default_param
    SET allowed_values = 'snake,lowerCamel,upperCamel',
        default_value = 'lowerCamel'
    WHERE name = 'json_casing' ;

/* Other potential options:

----

'api_schema', 'The schema to create standard API objects in.'
'json_api_schema', 'The schema to create JSON API objects in.'

a_test_schema

*/
