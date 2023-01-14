CREATE OR REPLACE FUNCTION util_meta.mk_get_function (
    a_object_schema text default null,
    a_object_name text default null,
    a_ddl_schema text default null,
    a_owner text default null,
    a_grantees text default null )
RETURNS text
LANGUAGE plpgsql stable
SECURITY DEFINER
AS $$
/**
Function mk_get_function generates a draft get item function for a table.

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

ASSERTIONS

 * In the schema that the get function will be created in there will be:

   1. a view for the table (mk_view)

   2. a function for resolving the ID of the table (mk_resolve_id_function)

*/

DECLARE

    r record ;

    l_ddl_schema text ;
    l_doc_item text ;
    l_full_view_name text ;
    l_func_name text ;
    l_local_var_names text[] ;
    l_local_types text[] ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;
    l_pk_column_name text ;
    l_pk_data_type text ;
    l_pk_param text ;
    l_resolve_id_func text ;
    l_resolve_id_params text[] ;
    l_result text ;
    l_table_noun text ;
    l_view_name text ;
    l_where_clause text ;
    l_resolve_id text;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    --------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta.table_noun ( a_object_name, l_ddl_schema ) ;
    l_func_name := 'get_' || l_table_noun ;

    l_view_name := regexp_replace ( a_object_name, '^([drs])t_', '\1v_' ) ;
    l_full_view_name := concat_ws ( '.', l_ddl_schema, l_view_name ) ;

    l_doc_item := 'Returns the specified '
        || replace ( l_table_noun, '_', ' ' ) || ' entry' ;

    l_resolve_id_func := concat_ws ( '_', 'resolve', l_table_noun, 'id' ) ;

    --------------------------------------------------------------------
    -- Ensure that the view is valid
    IF NOT util_meta.is_valid_object ( l_ddl_schema, l_view_name, 'view' ) THEN
        RETURN 'ERROR: required view (' || l_full_view_name || ') does not exist' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_local_var_names := array_append ( l_local_var_names, 'l_has_permission' ) ;
    l_local_types := array_append ( l_local_types, 'boolean' ) ;

    ----------------------------------------------------------------------------
    -- Obtain the parameters for resolving the entry
    FOR r IN (
        SELECT schema_name,
                object_name,
                column_name,
                data_type,
                is_pk,
                is_nk,
                'a_' || column_name AS param_name,
                'l_' || column_name AS local_param_name,
                trim ( coalesce ( comments, 'TBD' ) ) AS comments
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
                AND ( is_pk
                    OR is_nk )
            ORDER BY ordinal_position ) LOOP

        l_param_names := array_append ( l_param_names, r.param_name ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, r.data_type ) ;
        l_param_comments := array_append ( l_param_comments, r.comments ) ;

        l_resolve_id_params := array_append ( l_resolve_id_params, r.param_name ) ;

        IF r.is_pk THEN
            l_pk_data_type := r.data_type ;
            l_pk_column_name := r.column_name ;
        END IF ;

    END LOOP ;


    IF array_length ( l_resolve_id_params, 1 ) = 1 THEN
        -- assert that this is for the pk column
        --if there is only the pk parameter for the table then no id lookup is needed

        l_pk_param := 'a_' || l_pk_column_name ;

    ELSIF array_length ( l_resolve_id_params, 1 ) > 1 THEN

        l_pk_param := 'l_' || l_pk_column_name ;

        l_local_var_names := array_append ( l_local_var_names, l_pk_param ) ;
        l_local_types := array_append ( l_local_types, l_pk_data_type ) ;

        l_resolve_id := util_meta.snippet_resolve_id (
            a_id_param => l_pk_param,
            a_function_schema => l_ddl_schema,
            a_function_name => l_resolve_id_func,
            a_resolve_id_params => l_resolve_id_params ) ;

    ELSE
        RETURN 'ERROR: could not resolve PK parameter' ;

    END IF ;

    l_where_clause := concat_ws ( ' ',  l_pk_column_name, '=', l_pk_param ) ;

    ----------------------------------------------------------------------------
    l_param_names := array_append ( l_param_names, 'a_user' ) ;
    l_param_directions := array_append ( l_param_directions, 'in' ) ;
    l_param_types := array_append ( l_param_types, 'text' ) ;
    l_param_comments := array_append ( l_param_comments, 'The ID or username of the user requesting the entry' ) ;

    ----------------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        l_result,
        util_meta.snippet_function_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_return_type =>l_full_view_name,
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
        util_meta.snippet_declare_variables (
            a_var_names => l_local_var_names,
            a_var_datatypes => l_local_types ),
        '',
        'BEGIN' ) ;

    IF l_resolve_id IS NOT NULL THEN
        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            '',
            l_resolve_id ) ;
    END IF ;

    l_result := concat_ws ( util_meta.new_line (),
        l_result,
        util_meta.snippet_get_permissions (
            a_action => 'select',
            a_ddl_schema => l_ddl_schema,
            a_object_type => l_table_noun,
            a_id_param => l_pk_param ),
        '',
        util_meta.indent (1) || 'RETURN QUERY',
        util_meta.indent (2) || 'SELECT *',
        util_meta.indent (3) || 'FROM ' || l_full_view_name,
        util_meta.indent (3) || 'WHERE l_has_permission',
        util_meta.indent (4) || 'AND ' || l_where_clause || ' ;',
        util_meta.snippet_function_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_comment => l_doc_item,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_datatypes => l_param_types ) ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
