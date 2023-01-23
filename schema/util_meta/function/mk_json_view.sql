CREATE OR REPLACE FUNCTION util_meta.mk_json_view (
    a_object_schema text default null,
    a_object_name text default null,
    a_ddl_schema text default null,
    a_owner text default null,
    a_grantees text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function mk_json_view generates a draft view of a table in JSON format

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to wrap with the json view |
| a_object_name                  | in     | text       | The (name of the) table/view to wrap with the JSON view |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the JSON view in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the JSON view |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted on the JSON view |

Note that this should work for dv_, rv_, and sv_ views

Note that JSON objects schema defaults to the concatenation of a_object_schema with '_json'

*/
DECLARE

    r record ;

    l_columns text[] ;
    l_ddl_schema text ;
    l_full_object_name text ;
    l_full_view_name text ;
    l_object_alias text := 't0' ;
    l_result text ;
    l_view_comments text ;
    l_view_name text ;

BEGIN

    --------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'view' ) THEN
        IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
            RETURN 'ERROR: invalid object' ;
        END IF ;
    END IF ;

    ----------------------------------------------------------------------------
    FOR r IN (
        SELECT coalesce ( comments, 'TBD' ) || ' (as JSON)' AS comments
            FROM util_meta.objects
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name ) LOOP

        l_view_comments := r.comments ;

    END LOOP ;

    --------------------------------------------------------------------
    l_ddl_schema := coalesce (  a_ddl_schema, a_object_schema || '_json' ) ;
    l_view_name := regexp_replace ( a_object_name, '^([drs])[tv]_', '\1j_' ) ;
    l_full_view_name := concat_ws ( '.', l_ddl_schema, l_view_name ) ;
    l_full_object_name := concat_ws ( '.', a_object_schema, a_object_name ) ;

    FOR r IN (
        SELECT column_name,
                l_object_alias || '.' || column_name AS full_column_name,
                util_meta.json_identifier ( column_name ) AS json_alias,
                ordinal_position
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
            ORDER BY ordinal_position ) LOOP

        IF r.json_alias = r.column_name THEN
            l_columns := array_append ( l_columns, r.full_column_name ) ;
        ELSE
            l_columns := array_append ( l_columns, concat_ws ( ' ', r.full_column_name, 'AS', quote_ident ( r.json_alias ) ) ) ;
        END IF ;

    END LOOP ;

    l_result := concat_ws ( util_meta.new_line (),
        'CREATE OR REPLACE VIEW ' || l_full_view_name,
        'AS',
        'WITH t AS (',
        util_meta.indent (1) || 'SELECT ' || array_to_string ( l_columns, ',' || util_meta.new_line () || util_meta.indent (3) ),
        util_meta.indent (2) || concat_ws ( ' ', 'FROM', l_full_object_name, l_object_alias ),
        ')',
        'SELECT json_agg ( row_to_json ( t ) ) AS json',
        util_meta.indent (1) || 'FROM t ;',
        '',
        util_meta.snippet_owners_and_grants (
            a_ddl_schema => l_ddl_schema,
            a_object_name => l_view_name,
            a_object_type => 'view',
            a_owner => a_owner,
            a_grantees => a_grantees ),
        '',
        util_meta.snippet_object_comment (
            a_ddl_schema => l_ddl_schema,
            a_object_name => l_view_name,
            a_object_type => 'view',
            a_comment => l_view_comments ) ,
        '' ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
