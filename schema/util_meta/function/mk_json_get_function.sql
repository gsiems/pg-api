CREATE OR REPLACE FUNCTION util_meta.mk_json_get_function (
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
Function mk_json_get_function generates a draft JSON wrapper around a regular get function (as created by mk_get_function)

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the regular get function |
| a_object_name                  | in     | text       | The (name of the) name of the regular get function |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the json function in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the json function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted on the json function |

Note that JSON objects schema defaults to the concatenation of a_object_schema with '_json'

*/
DECLARE

    r record;

    l_result text ;

    l_calling_params text [ ] ;
    l_calling_types text [ ] ;
    l_column_alias text ;
    l_column_comment text ;
    l_column_name text ;
    l_columns text [ ] ;
    l_ddl_schema text ;
    l_doc_item text ;
    l_func_name text ;
    l_param_comments text [ ] ;
    l_param_directions text [ ] ;
    l_param_names text [ ] ;
    l_param_name text ;
    l_param_types text [ ] ;
    l_param_type text ;
    l_proc_params text [ ] ;
    l_view_name text ;
    l_type_name text ;
    l_full_type_name text ;
    l_full_view_name text ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'function' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce (  a_ddl_schema, a_object_schema || '_json' ) ;
    l_func_name := a_object_name ;
    l_type_name := regexp_replace ( a_object_name, '^get_', 'ut_' ) ;
    l_view_name := regexp_replace ( a_object_name, '^get_', 'dv_' ) ;
    l_full_view_name := a_object_schema || '.' || l_view_name ;
    l_full_type_name := l_ddl_schema || '.' || l_type_name ;

    l_doc_item := 'Returns the results of the ' || a_object_schema || '.' || a_object_name || ' function as JSON' ;

    ----------------------------------------------------------------------------
    FOR r IN (
        WITH args AS (
            SELECT a_object_schema AS schema_name,
                    a_object_name AS object_name,
                    l_view_name AS view_name,
                    l_full_view_name AS full_view_name
        ),
        p1 AS (
            SELECT args.schema_name,
                    args.object_name,
                    args.view_name,
                    args.full_view_name,
                    trim ( regexp_replace ( unnest ( string_to_array ( lower ( objects.calling_arguments ), ',' ) ), ' default.+$', '' ) ) AS param
                FROM util_meta.objects
                JOIN args
                    ON ( args.schema_name = objects.schema_name
                        AND args.object_name = objects.object_name )
        ),
        p2 AS (
            SELECT p1.schema_name,
                    p1.object_name,
                    p1.view_name,
                    p1.full_view_name,
                    split_part ( p1.param, ' ', 1 ) AS param_name,
                    split_part ( p1.param, ' ', 2 ) AS param_type,
                    p1.param,
                    regexp_replace ( split_part ( p1.param, ' ', 1 ), '^a_', '' ) AS column_name
                FROM p1
        )
        SELECT p2.schema_name,
                p2.object_name,
                p2.view_name,
                p2.param_name,
                p2.param_type,
                p2.param,
                p2.column_name,
                coalesce ( columns.comments, 'TBD' ) AS comments
            FROM p2
            LEFT JOIN util_meta.columns
                ON ( columns.full_object_name = p2.full_view_name
                    AND columns.column_name = p2.column_name ) ) LOOP

        -- TODO deal with preceeding IN, OUT, INOUT?

        l_param_name := split_part ( r.param, ' ', 1 ) ;
        l_param_type := split_part ( r.param, ' ', 2 ) ;

        l_param_names := array_append ( l_param_names, r.param_name ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, r.param_type ) ;
        l_param_comments := array_append ( l_param_comments, r.comments ) ;

        l_proc_params := array_append ( l_proc_params, concat_ws ( ' ', r.param_name, '=>', r.param_name ) ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- ASSERTION: the function being wrapped and the view being used by the function
    -- are in the same schema
    FOR r IN (
        SELECT --schema_name,
                --object_name,
                column_name,
                data_type,
                'a_' || column_name AS param_name
            FROM util_meta.columns
            WHERE full_object_name = l_full_view_name
            ORDER BY ordinal_position ) LOOP

        l_column_alias := util_meta.json_identifier ( r.column_name ) ;

        IF l_column_alias = r.column_name THEN
            l_columns := array_append ( l_columns, r.column_name ) ;
        ELSE
            l_columns := array_append ( l_columns, concat_ws ( ' ', r.column_name, 'AS', quote_ident ( l_column_alias ) ) ) ;
        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        util_meta.snippet_function_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'sql',
            a_return_type => 'text',
            a_returns_set => false,
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
        util_meta.indent (1) || 'WITH t AS (',
        util_meta.indent (2) || 'SELECT ' || array_to_string ( l_columns, ',' || util_meta.new_line () || util_meta.indent (4) ),
        util_meta.indent (3) || 'FROM ' || a_object_schema || '.' || a_object_name || ' (',
        util_meta.indent (5) || array_to_string ( l_proc_params, ',' || util_meta.new_line () || util_meta.indent (5) ),
        util_meta.indent (4) || ')',
        util_meta.indent (1) || ')',
        util_meta.indent (1) || 'SELECT json_agg ( row_to_json ( t ) ) AS json',
        util_meta.indent (2) || 'FROM t ;',
        '',
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
