CREATE OR REPLACE FUNCTION util_meta.mk_json_function_wrapper (
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
Function mk_json_function_wrapper generates a draft JSON wrapper around a
regular set returning function ( find_, get_, list_ )

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the regular function |
| a_object_name                  | in     | text       | The (name of the) name of the regular function     |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the json function in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the json function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted on the json function |

Note that JSON objects schema defaults to the concatenation of a_object_schema with '_json'

ASSERTIONS

 * The function being wrapped uses a view as the return type

*/
DECLARE

    r record;

    l_result text ;

    l_calling_params text[] ;
    l_calling_types text[] ;
    l_column_alias text ;
    l_column_comment text ;
    l_column_name text ;
    l_columns text[] ;
    l_ddl_schema text ;
    l_doc_item text ;
    l_full_view_name text ;
    l_func_name text ;
    l_func_type text ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_name text ;
    l_param_types text[] ;
    l_param_type text ;
    l_proc_params text[] ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'function' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce (  a_ddl_schema, a_object_schema || '_json' ) ;
    l_func_name := a_object_name ;
    l_func_type := split_part ( a_object_name, '_', 1 ) ;

    FOR r IN (
        SELECT regexp_match ( result_data_type, '([^ ]+)$' ) AS view_name
            FROM util_meta.objects
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name ) LOOP

        l_full_view_name := r.view_name[1] ;

    END LOOP ;

    IF l_full_view_name IS NULL THEN
        RETURN 'ERROR: could not find view' ;
    END IF ;

    l_doc_item := 'Returns the results of the ' || a_object_schema || '.' || a_object_name || ' function as JSON' ;

    ----------------------------------------------------------------------------
    FOR r IN (
        WITH args AS (
            SELECT schema_name,
                    object_name,
                    object_type,
                    param_name,
                    data_type,
                    param_default,
                    param_direction,
                    arg_position,
                    l_full_view_name AS full_view_name,
                    column_name,
                    comments
                FROM util_meta.calling_parameters (
                    a_object_schema => a_object_schema,
                    a_object_name => a_object_name,
                    a_object_type => 'function' )
        )
        SELECT args.schema_name,
                args.object_name,
                args.object_type,
                args.param_name,
                args.data_type,
                args.param_default,
                args.param_direction,
                args.arg_position,
                args.full_view_name,
                columns.column_name,
                coalesce ( columns.comments, args.comments, 'TBD' ) AS comments
            FROM args
            LEFT JOIN util_meta.columns
                ON ( columns.full_object_name = args.full_view_name
                    AND columns.column_name = args.column_name ) ) LOOP

        l_param_names := array_append ( l_param_names, r.param_name ) ;
        l_param_directions := array_append ( l_param_directions, r.param_direction ) ;
        l_param_types := array_append ( l_param_types, r.data_type ) ;
        l_param_comments := array_append ( l_param_comments, r.comments ) ;

        l_proc_params := array_append ( l_proc_params, concat_ws ( ' ', r.param_name, '=>', r.param_name ) ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- ASSERTION: the function being wrapped and the view being used by the function
    -- are in the same schema
    FOR r IN (
        SELECT column_name,
                util_meta.json_identifier ( column_name ) AS json_alias
            FROM util_meta.columns
            WHERE full_object_name = l_full_view_name
            ORDER BY ordinal_position ) LOOP

        IF r.json_alias = r.column_name THEN
            l_columns := array_append ( l_columns, r.column_name ) ;
        ELSE
            l_columns := array_append ( l_columns, concat_ws ( ' ', r.column_name, 'AS', quote_ident ( r.json_alias ) ) ) ;
        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        l_result,
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
        util_meta.indent (1) || ')' ) ;

    -- TODO: need a better way of determining single tuple results vs multi-tuple results
    IF l_func_type = 'get' THEN

        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            util_meta.indent (1) || 'SELECT row_to_json ( t ) AS json',
            util_meta.indent (2) || 'FROM t ;' ) ;

    ELSE

        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            util_meta.indent (1) || 'SELECT json_agg ( row_to_json ( t ) ) AS json',
            util_meta.indent (2) || 'FROM t ;' ) ;

    END IF ;

    l_result := concat_ws ( util_meta.new_line (),
        l_result,
        '',
        util_meta.snippet_function_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'sql',
            a_comment => l_doc_item,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_datatypes => l_param_types ) ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
