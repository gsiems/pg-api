CREATE OR REPLACE FUNCTION util_meta.mk_find_function (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_is_row_based boolean DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_find_function generates a draft "find matching entries" function for a table.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_is_row_based                 | in     | boolean    | Indicates if the permissions model is row-based (default is table based) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

ASSERTIONS

 * There will exist a view for the table in the same schema as the function to be created

*/
DECLARE

    r record ;

    l_ddl_schema text ;
    l_doc_item text ;
    l_found_cte text ;
    l_func_name text ;
    l_is_row_based boolean ;
    l_join_clause text[] ;
    l_pk_cols text[] ;
    l_result text ;
    l_search_cols text[] ;
    l_select text ;
    l_table_noun text ;

    l_calling_params util_meta.ut_parameters ;
    l_local_vars util_meta.ut_parameters ;
    l_base_view util_meta.ut_object ;

BEGIN

    --------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    --------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta.table_noun ( a_object_name, l_ddl_schema ) ;

    l_func_name := 'find_' || l_table_noun ;
    l_base_view := util_meta.find_view (
        a_proc_schema => a_ddl_schema,
        a_table_schema => a_object_schema,
        a_table_name => a_object_name ) ;

    l_doc_item := 'Returns the list of matching ' || replace ( l_table_noun, '_', ' ' ) || ' entries' ;

    --------------------------------------------------------------------
    -- Ensure that the view is valid
    IF l_base_view.object_name IS NULL THEN
        RETURN 'ERROR: required view for (' || a_object_name || ') not found' ;
    END IF ;

    l_is_row_based := coalesce ( a_is_row_based, false ) ;

    ----------------------------------------------------------------------------
    IF l_is_row_based THEN

        l_local_vars := util_meta.append_parameter (
            a_parameters => l_local_vars,
            a_name => 'r',
            a_datatype => 'record' ) ;

    END IF ;

    l_local_vars := util_meta.append_parameter (
        a_parameters => l_local_vars,
        a_name => 'l_has_permission',
        a_datatype => 'boolean' ) ;

    ----------------------------------------------------------------------------
    l_calling_params := util_meta.append_parameter (
        a_parameters => l_calling_params,
        a_name => 'a_user',
        a_datatype => 'text',
        a_description => 'The ID or username of the user doing the search' ) ;

    l_calling_params := util_meta.append_parameter (
        a_parameters => l_calling_params,
        a_name => 'a_search_term',
        a_datatype => 'text',
        a_description => 'The string to search for' ) ;

    FOR r IN (
        SELECT schema_name,
                object_name,
                column_name,
                ordinal_position,
                data_type,
                is_pk,
                is_nk
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
                AND ( is_pk
                    OR is_nk )
            ORDER BY ordinal_position ) LOOP

        IF r.is_pk OR r.is_nk THEN
            l_search_cols := array_append ( l_search_cols, r.column_name ) ;
        END IF ;

        IF r.is_pk THEN
            l_pk_cols := array_append ( l_pk_cols, r.column_name ) ;
            l_join_clause := array_append ( l_join_clause, 'found.' || r.column_name || ' = de.' || r.column_name ) ;
        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta.new_line (),
        util_meta.snippet_function_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_return_type => l_base_view.full_object_name,
            a_returns_set => true,
            a_calling_parameters => l_calling_params ),
        util_meta.snippet_documentation_block (
            a_object_name => l_func_name,
            a_object_type => 'function',
            a_object_purpose => l_doc_item,
            a_calling_parameters => l_calling_params ),
        util_meta.snippet_declare_variables ( a_variables => l_local_vars ),
        '',
        'BEGIN',
        '',
        util_meta.indent ( 1 )
            || '-- TODO: review this as different applications may have different permissions models.',
        util_meta.indent ( 1 ) || '-- TODO: verify the columns to search on' ) ;

    ----------------------------------------------------------------------------
    l_found_cte := concat_ws (
        util_meta.new_line (),
        util_meta.indent ( 2 ) || 'found AS (',
        util_meta.indent ( 3 )
            || 'SELECT '
            || array_to_string ( l_pk_cols, ',' || util_meta.new_line () || util_meta.indent ( 6 ) ),
        util_meta.indent ( 4 ) || 'FROM base',
        util_meta.indent ( 4 ) || 'WHERE ( ( a_search_term IS NOT NULL',
        util_meta.indent ( 7 ) || 'AND trim ( a_search_term ) <> ' || quote_literal ( '' ),
        util_meta.indent ( 7 ) || 'AND lower ( base::text ) ~ lower ( a_search_term ) )',
        util_meta.indent ( 6 )
            || 'OR ( trim ( coalesce ( a_search_term, '
            || quote_literal ( '' )
            || ' ) ) = '
            || quote_literal ( '' )
            || ' ) )',
        util_meta.indent ( 2 ) || ')' ) ;

    ----------------------------------------------------------------------------
    l_select := concat_ws (
        util_meta.new_line (),
        util_meta.indent ( 2 ) || 'SELECT de.*',
        util_meta.indent ( 3 ) || 'FROM ' || l_base_view.full_object_name || ' de',
        util_meta.indent ( 3 ) || 'JOIN found',
        util_meta.indent ( 4 )
            || 'ON ( '
            || array_to_string ( l_join_clause, util_meta.new_line () || util_meta.indent ( 5 ) || 'AND ' )
            || ' )' ) ;

    ----------------------------------------------------------------------------
    l_is_row_based := coalesce ( a_is_row_based, false ) ;
    IF l_is_row_based THEN

        l_result := concat_ws (
            util_meta.new_line (),
            l_result,
            util_meta.indent ( 1 ) || '-- ASSERTION: the permissions model is row (as opposed to table) based.',
            '',
            util_meta.indent ( 1 ) || 'FOR r IN (',
            util_meta.indent ( 2 ) || 'WITH base AS (',
            util_meta.indent ( 3 )
                || 'SELECT '
                || array_to_string ( l_search_cols, ',' || util_meta.new_line () || util_meta.indent ( 5 ) ),
            util_meta.indent ( 4 ) || 'FROM ' || l_base_view.full_object_name,
            util_meta.indent ( 2 ) || '),',
            l_found_cte,
            l_select,
            util_meta.indent ( 2 ) || ') LOOP',
            util_meta.snippet_get_permissions (
                a_indents => 1,
                a_ddl_schema => l_ddl_schema,
                a_object_type => l_table_noun,
                a_action => 'select',
                a_id_param => 'r.' || l_pk_cols[1] ),
            '',
            util_meta.indent ( 2 ) || 'IF l_has_permission THEN',
            util_meta.indent ( 3 ) || 'RETURN NEXT r ;',
            util_meta.indent ( 2 ) || 'END IF ;',
            '',
            util_meta.indent ( 1 ) || 'END LOOP ;' ) ;

    ELSE

        -- is table based

        l_result := concat_ws (
            util_meta.new_line (),
            l_result,
            util_meta.indent ( 1 ) || '-- ASSERTION: the permissions model is table (as opposed to row) based.',
            util_meta.snippet_get_permissions (
                a_ddl_schema => l_ddl_schema,
                a_object_type => l_table_noun,
                a_action => 'select',
                a_id_param => 'null' ),
            '',
            util_meta.indent ( 1 ) || 'RETURN QUERY',
            util_meta.indent ( 2 ) || 'WITH base AS (',
            util_meta.indent ( 3 )
                || 'SELECT '
                || array_to_string ( l_search_cols, ',' || util_meta.new_line () || util_meta.indent ( 5 ) ),
            util_meta.indent ( 4 ) || 'FROM ' || l_base_view.full_object_name,
            util_meta.indent ( 4 ) || 'WHERE l_has_permission',
            util_meta.indent ( 2 ) || '),',
            l_found_cte,
            l_select || ' ;' ) ;

    END IF ;

    l_result := concat_ws (
        util_meta.new_line (),
        l_result,
        util_meta.snippet_function_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_comment => l_doc_item,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_calling_parameters => l_calling_params ) ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
