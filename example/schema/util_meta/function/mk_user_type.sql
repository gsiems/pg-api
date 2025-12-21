CREATE OR REPLACE FUNCTION util_meta.mk_user_type (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_user_type generates a user defined type for a table or view

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to create a user type from |
| a_object_name                  | in     | text       | The (name of the) table/view to create a user type from |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the type in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the type |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted privs on the type |

*/
DECLARE

    r record ;

    l_result text ;

    l_columns text[] ;
    l_comments text[] ;
    l_ddl_schema text ;
    l_full_type_name text ;
    l_type_name text ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta._is_valid_object ( a_object_schema, a_object_name, 'view' ) THEN
        IF NOT util_meta._is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
            RETURN 'ERROR: invalid object' ;
        END IF ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_type_name := regexp_replace ( util_meta._to_singular ( a_object_name ), '^[a-z][mtv]_', 'ut_' ) ;
    l_full_type_name := concat_ws ( '.', l_ddl_schema, l_type_name ) ;

    ----------------------------------------------------------------------------
    -- Determine the comment for the user type
    FOR r IN (
        SELECT schema_name,
                object_name,
                object_type,
                comments
            FROM util_meta.objects
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name ) LOOP

        l_comments := array_append (
            l_comments,
            util_meta._snip_object_comment (
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
                data_type,
                ordinal_position
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
            ORDER BY ordinal_position ) LOOP

        l_columns := array_append ( l_columns, util_meta._indent ( 1 ) || r.column_name || ' ' || r.data_type ) ;

    END LOOP ;

    l_result := concat_ws (
        util_meta._new_line (),
        'CREATE TYPE ' || l_full_type_name || ' AS (',
        array_to_string ( l_columns, ',' || util_meta._new_line () ) || ' ) ;',
        '',
        util_meta._snip_owners_and_grants (
            a_ddl_schema => a_ddl_schema,
            a_object_name => l_type_name,
            a_object_type => 'type',
            a_owner => a_owner,
            a_grantees => a_grantees ),
        '',
        array_to_string ( l_comments, util_meta._new_line () ),
        '' ) ;

    RETURN util_meta._cleanup_whitespace ( l_result ) ;

END ;
$$ ;
