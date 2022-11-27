CREATE OR REPLACE FUNCTION util_meta.mk_json_find_function (
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
Function mk_json_find_function generates a draft JSON wrapper around a regular find function (as created by mk_find_function)

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the regular find function |
| a_object_name                  | in     | text       | The (name of the) name of the regular find function |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the json function in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the json function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted on the json function |

Note that JSON objects schema defaults to the concatenation of a_object_schema with '_json'

*/
DECLARE

    r record;

    l_column_alias text ;
    l_columns text [ ] ;
    l_json_columns text [ ] ;
    l_ddl_schema text ;
    l_doc_item text ;
    l_func_name text ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;
    l_result text ;
    l_view_name text ;
    l_type_name text ;
    l_full_type_name text ;
    l_proc_args text[] ;

BEGIN

    --------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'function' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce (  a_ddl_schema, a_object_schema || '_json' ) ;
    l_func_name := a_object_name ;
    l_type_name := regexp_replace ( a_object_name, '^find_', 'ut_' ) ;
    l_view_name := regexp_replace ( a_object_name, '^find_', 'dv_' ) ;
    l_full_type_name := l_ddl_schema || '.' || l_type_name ;

    IF NOT util_meta.is_valid_object ( l_ddl_schema, l_type_name, 'type' ) THEN
        RETURN 'ERROR: required type ' || l_full_type_name || ' does not exist' ;
    END IF ;

    l_doc_item := 'Returns the results of the ' || a_object_schema || '.' || a_object_name || ' function as JSON' ;

    ----------------------------------------------------------------------------
    l_param_names := array_append ( l_param_names, 'a_user' ) ;
    l_param_directions := array_append ( l_param_directions, 'in' ) ;
    l_param_types := array_append ( l_param_types, 'text' ) ;
    l_param_comments := array_append ( l_param_comments, 'The ID or username of the user doing the search' ) ;
    l_proc_args := array_append ( l_proc_args, 'a_user => a_user' ) ;

    l_param_names := array_append ( l_param_names, 'a_search_term' ) ;
    l_param_directions := array_append ( l_param_directions, 'in' ) ;
    l_param_types := array_append ( l_param_types, 'text' ) ;
    l_param_comments := array_append ( l_param_comments, 'The string to search for' ) ;
    l_proc_args := array_append ( l_proc_args, 'a_search_term => a_search_term' ) ;

    ----------------------------------------------------------------------------
    -- ASSERTION: the function being wrapped and the user type being used by the
    -- function are in the same schema
    FOR r IN (
        SELECT column_name,
                util_meta.json_identifier ( column_name ) AS column_alias
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = l_view_name
            ORDER BY ordinal_position ) LOOP

        IF r.column_alias = r.column_name THEN
            l_columns := array_append ( l_columns, r.column_name ) ;
            l_json_columns := array_append ( l_json_columns, r.column_name ) ;
        ELSE
            l_columns := array_append ( l_columns, concat_ws ( ' ', r.column_name, 'AS', quote_ident ( r.column_alias ) ) ) ;
            l_json_columns := array_append ( l_json_columns, quote_ident ( r.column_alias ) ) ;
        END IF ;

    END LOOP ;

    --------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        util_meta.snippet_function_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'sql',
            a_return_type => 'text',
            a_returns_set => true,
            a_param_names => l_param_names,
            a_directions => l_param_directions,
            a_datatypes => l_param_types ),
        util_meta.snippet_documentation_block (
            a_object_name => l_func_name,
            a_object_type => 'function',
            a_object_purpose => l_doc_item,
            a_param_names => l_param_names,
            a_directions => l_param_directions,
            a_datatypes => l_param_types,
            a_comments => l_param_comments ),
        '',
        'WITH t AS (',
        util_meta.indent (1) || 'SELECT ' || array_to_string ( l_columns, ',' || util_meta.new_line () || util_meta.indent (3) ),
        util_meta.indent (2) || 'FROM ' || l_ddl_schema || '.' || l_func_name || ' (',
        util_meta.indent (4) || array_to_string ( l_proc_args, ',' || util_meta.new_line () || util_meta.indent (4) ),
        util_meta.indent (3) || ')',
        ')',
        'SELECT json_agg ( row_to_json ( cast ( row ( ',
        util_meta.indent (3) || array_to_string ( l_json_columns, ',' || util_meta.new_line () || util_meta.indent (3) || '' ) || ' ) AS ' || l_full_type_name  || ' ) ) ) AS json',
        util_meta.indent (1) || 'FROM t ;',
        util_meta.snippet_function_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'sql',
            a_comment => l_doc_item,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_datatypes => l_param_types ) ) ;

    RETURN l_result ;

END ;
$$ ;
