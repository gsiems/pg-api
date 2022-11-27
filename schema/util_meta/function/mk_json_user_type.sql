CREATE OR REPLACE FUNCTION util_meta.mk_json_user_type (
    a_object_schema text default null,
    a_object_name text default null,
    a_ddl_schema text default null,
    a_cast_booleans_as text default null,
    a_owner text default null,
    a_grantees text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function mk_json_user_type generates a user type for a table or view with lowerCamelCase column names

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to create a user type from |
| a_object_name                  | in     | text       | The (name of the) table/view to create a user type from |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the type in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the type |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted select on the view |

*/
DECLARE

    r record ;

    l_result text ;

    l_column_name text ;
    l_columns text[] ;
    l_comments text[] ;
    l_ddl_schema text ;
    l_full_type_name text ;
    l_type_name text ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'view' ) THEN
        IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
            RETURN 'ERROR: invalid object' ;
        END IF ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_type_name := regexp_replace ( a_object_name, '^[drs][tv]_', 'ut_' ) ;
    l_full_type_name := concat_ws ( '.', l_ddl_schema, l_type_name ) ;

    ----------------------------------------------------------------------------
    -- Determine the comment for the view
    FOR r IN (
        SELECT schema_name,
                object_name,
                object_type,
                comments
            FROM util_meta.objects
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name ) LOOP

        l_comments := array_append ( l_comments,
            util_meta.snippet_object_comment (
                a_ddl_schema => l_ddl_schema,
                a_object_name => l_type_name,
                a_object_type => 'type',
                a_comment => 'User type for: ' || a_object_schema || '.' || a_object_name ) ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    FOR r IN (
        SELECT schema_name,
                object_name,
                column_name,
                util_meta.json_identifier ( column_name ) AS json_alias,
                data_type,
                ordinal_position
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
            ORDER BY ordinal_position ) LOOP

        IF r.json_alias = r.column_name THEN
            l_columns := array_append ( l_columns, util_meta.indent (1) || r.column_name || ' ' || r.data_type ) ;
        ELSE
            l_columns := array_append ( l_columns, util_meta.indent (1) || quote_ident ( r.json_alias ) || ' ' || r.data_type ) ;
        END IF ;

    END LOOP ;

    l_result := concat_ws ( util_meta.new_line (),
        'CREATE TYPE ' || l_full_type_name || ' AS (',
        array_to_string ( l_columns, ',' || util_meta.new_line () ) || ' ) ;',
        '',
        util_meta.snippet_owners_and_grants (
            a_ddl_schema => a_ddl_schema,
            a_object_name => l_type_name,
            a_object_type => 'type',
            a_owner => a_owner,
            a_grantees => a_grantees ),
        '',
        array_to_string ( l_comments, util_meta.new_line () ) ) ;

    RETURN l_result ;

END ;
$$ ;
