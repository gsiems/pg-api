CREATE OR REPLACE FUNCTION util_meta.mk_list_function (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_exclude_binary_data boolean DEFAULT NULL,
    --a_insert_audit_columns text DEFAULT NULL,
    --a_update_audit_columns text DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
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

*/
DECLARE

    r record ;

    l_ddl_schema text ;
    l_doc_item text ;
    l_exclude_binary_data boolean ;
    l_func_name text ;

    l_result text ;
    l_select_cols text[] ;
    l_select text ;
    l_table_noun text ;

    l_local_vars util_meta.ut_parameters ;
    l_calling_params util_meta.ut_parameters ;
    l_base_view util_meta.ut_object ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta._is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta._table_noun ( a_object_name, l_ddl_schema ) ;
    l_func_name := util_meta._to_plural ( 'list_' || l_table_noun ) ;

    l_base_view := util_meta._find_view (
        a_proc_schema => a_ddl_schema,
        a_table_schema => a_object_schema,
        a_table_name => a_object_name ) ;

    --------------------------------------------------------------------
    -- Ensure that the view is valid
    IF l_base_view.object_name IS NULL THEN
        RETURN 'ERROR: required view for (' || a_object_name || ') not found' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_exclude_binary_data := coalesce ( a_exclude_binary_data, false ) ;

    l_local_vars := util_meta._append_parameter (
        a_parameters => l_local_vars,
        a_name => 'l_has_permission',
        a_datatype => 'boolean' ) ;

    ----------------------------------------------------------------------------
    l_calling_params := util_meta._append_parameter (
        a_parameters => l_calling_params,
        a_name => 'a_user',
        a_datatype => 'text',
        a_description => 'The ID or username of the user requesting the list' ) ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        util_meta._snip_function_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_return_type => l_base_view.full_object_name,
            a_returns_set => true,
            a_calling_parameters => l_calling_params ),
        util_meta._snip_documentation_block (
            a_object_name => l_func_name,
            a_object_type => 'function',
            a_object_purpose => l_doc_item,
            a_calling_parameters => l_calling_params ),
        util_meta._snip_declare_variables ( a_variables => l_local_vars ),
        '',
        'BEGIN',
        '',
        util_meta._indent ( 1 )
            || '-- TODO: review this as different applications may have different permissions models.',
        util_meta._indent ( 1 )
            || '-- As written, this asserts that the permissions model is table (as opposed to row) based.' ) ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        util_meta._snip_get_permissions (
            a_action => 'select',
            a_ddl_schema => l_ddl_schema ) ) ;

    ----------------------------------------------------------------------------
    IF l_exclude_binary_data THEN

        FOR r IN (
            SELECT schema_name,
                    object_name,
                    column_name,
                    ordinal_position,
                    data_type,
                    is_pk,
                    is_nk
                FROM util_meta.columns
                WHERE schema_name = l_ddl_schema
                    AND object_name = l_base_view.object_name
                ORDER BY ordinal_position ) LOOP

            IF l_exclude_binary_data AND r.data_type IN ( 'bytea', 'jsonb' ) THEN
                l_select_cols := array_append ( l_select_cols, 'null::' || r.data_type || ' AS ' || r.column_name ) ;
            ELSE
                l_select_cols := array_append ( l_select_cols, r.column_name ) ;
            END IF ;

        END LOOP ;

        l_select := util_meta._indent ( 2 )
            || 'SELECT '
            || array_to_string ( l_select_cols, ',' || util_meta._new_line () || util_meta._indent ( 4 ) ) ;

    ELSE

        l_select := util_meta._indent ( 2 ) || 'SELECT *' ;

    END IF ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        '',
        util_meta._indent ( 1 ) || 'RETURN QUERY',
        l_select,
        util_meta._indent ( 3 ) || 'FROM ' || l_base_view.full_object_name,
        util_meta._indent ( 3 ) || 'WHERE l_has_permission ;',
        util_meta._snip_function_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_comment => l_doc_item,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_calling_parameters => l_calling_params ) ) ;

    RETURN util_meta._cleanup_whitespace ( l_result ) ;

END ;
$$ ;
