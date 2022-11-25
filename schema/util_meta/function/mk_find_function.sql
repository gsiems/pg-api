CREATE OR REPLACE FUNCTION util_meta.mk_find_function (
    a_object_schema text default null,
    a_object_name text default null,
    a_ddl_schema text default null,
    a_is_row_based boolean default null,
    a_exclude_binary_data boolean default null,
    a_owner text default null,
    a_grantees text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function mk_find_function generates a draft "find matching entries" function for a table.

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_is_row_based                 | in     | boolean    | Indicates if the permissions model is row-based (default is table based) |
| a_exclude_binary_data          | in     | boolean    | Indicates if binary (bytea, jsonb) data is to be excluded from the result-set (default is to include binary data) |
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
    l_full_view_name text ;
    l_func_name text ;
    l_exclude_binary_data boolean ;
    l_is_row_based boolean ;
    l_join_clause text[] ;
    l_local_params text[]  ;
    l_local_types text[] ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;
    l_pk_cols text[] ;
    l_result text ;
    l_search_cols text[] ;
    l_select_cols text[] ;
    l_select text ;
    l_table_noun text ;
    l_view_name text ;

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
    l_view_name := regexp_replace ( a_object_name, '^([drs])t_', '\1v_' ) ;
    l_full_view_name := concat_ws ( '.', l_ddl_schema, l_view_name ) ;
    l_doc_item := 'Returns the list of matching ' || replace ( l_table_noun, '_', ' ' ) || ' entries';

    --------------------------------------------------------------------
    -- Ensure that the view is valid
    IF NOT util_meta.is_valid_object ( l_ddl_schema, l_view_name, 'view' ) THEN
        RETURN 'ERROR: required view (' || l_full_view_name || ') does not exist' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_is_row_based := coalesce ( a_is_row_based, false ) ;
    l_exclude_binary_data := coalesce ( a_exclude_binary_data, false ) ;

    IF l_is_row_based THEN
        l_local_params := array_append ( l_local_params, 'r' ) ;
        l_local_types := array_append ( l_local_types, 'record' ) ;
    END IF ;

    l_local_params := array_append ( l_local_params, 'l_has_permission' ) ;
    l_local_types := array_append ( l_local_types, 'boolean' ) ;

    l_param_names := array_append ( l_param_names, 'a_search_term' ) ;
    l_param_directions := array_append ( l_param_directions, 'in' ) ;
    l_param_types := array_append ( l_param_types, 'text' ) ;
    l_param_comments := array_append ( l_param_comments, 'The string to search for' ) ;

    l_param_names := array_append ( l_param_names, 'a_user' ) ;
    l_param_directions := array_append ( l_param_directions, 'in' ) ;
    l_param_types := array_append ( l_param_types, 'text' ) ;
    l_param_comments := array_append ( l_param_comments, 'The ID or username of the user doing the search' ) ;

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
    l_result := concat_ws ( util_meta.new_line (),
        util_meta.snippet_function_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_return_type => l_full_view_name,
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
            a_param_names => l_local_params,
            a_datatypes => l_local_types ),
        '',
        'BEGIN',
        '',
        util_meta.indent (1) || '-- TODO: review this as different applications may have different permissions models.',
        util_meta.indent (1) || '-- TODO: verify the columns to search on' ) ;

    ----------------------------------------------------------------------------
    l_found_cte := concat_ws ( util_meta.new_line (),
        util_meta.indent (2) || 'found AS (',
        util_meta.indent (3) || 'SELECT ' || array_to_string ( l_pk_cols, ',' || util_meta.new_line () || util_meta.indent (6) ),
        util_meta.indent (4) || 'FROM base',
        util_meta.indent (4) || 'WHERE ( ( a_search_term IS NOT NULL',
        util_meta.indent (7) || 'AND trim ( a_search_term ) <> ' || quote_literal ( '' ),
        util_meta.indent (7) || 'AND lower ( base::text ) ~ lower ( a_search_term ) )',
        util_meta.indent (6) || 'OR ( trim ( coalesce ( a_search_term, ' || quote_literal ( '' ) || ' ) ) = ' || quote_literal ( '' ) || ' ) )',
        util_meta.indent (2) || ')' ) ;

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
                    AND object_name = l_view_name
                ORDER BY ordinal_position ) LOOP

            IF l_exclude_binary_data AND r.data_type IN ( 'bytea', 'jsonb' ) THEN
                l_select_cols := array_append ( l_select_cols, 'null::' || r.data_type || ' AS ' || r.column_name ) ;
            ELSE
                l_select_cols := array_append ( l_select_cols, 'de.' || r.column_name ) ;
            END IF ;

        END LOOP ;

        l_select := concat_ws ( util_meta.new_line (),
            util_meta.indent (2) || 'SELECT ' || array_to_string ( l_select_cols, ',' || util_meta.new_line () || util_meta.indent (4) ),
            util_meta.indent (3) || 'FROM ' || l_full_view_name || ' de',
            util_meta.indent (3) || 'JOIN found',
            util_meta.indent (4) || 'ON ( ' || array_to_string ( l_join_clause, util_meta.new_line () || util_meta.indent (5) || 'AND' ) || ' )' ) ;

    ELSE

        l_select := concat_ws ( util_meta.new_line (),
            util_meta.indent (2) || 'SELECT de.*',
            util_meta.indent (3) || 'FROM ' || l_full_view_name || ' de',
            util_meta.indent (3) || 'JOIN found',
            util_meta.indent (4) || 'ON ( ' || array_to_string ( l_join_clause, util_meta.new_line () || util_meta.indent (5) || 'AND' ) || ' )' ) ;

    END IF ;

    ----------------------------------------------------------------------------
    IF l_is_row_based THEN

        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            util_meta.indent (1) || '-- ASSERTION: the permissions model is row (as opposed to table) based.',
            '',
            util_meta.indent (1) || 'FOR r IN (',
            util_meta.indent (2) || 'WITH base AS (',
            util_meta.indent (3) || 'SELECT ' || array_to_string ( l_search_cols, ',' || util_meta.new_line () || util_meta.indent (5) ),
            util_meta.indent (4) || 'FROM ' || l_full_view_name,
            util_meta.indent (2) || '),',
            l_found_cte,
            l_select,
            util_meta.indent (2) || ') LOOP',
            util_meta.snippet_get_permissions (
                a_ddl_schema => l_ddl_schema,
                a_object_type => l_table_noun,
                a_action => 'select',
                a_id_param => 'r.' || l_pk_cols[1],
                a_base_indent => 1 ),
            '',
            util_meta.indent (2) || 'IF l_has_permission THEN',
            util_meta.indent (3) || 'RETURN NEXT r ;',
            util_meta.indent (2) || 'END IF ;',
            '',
            util_meta.indent (1) || 'END LOOP ;' ) ;

    ELSE

        -- is table based

        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            util_meta.indent (1) || '-- ASSERTION: the permissions model is table (as opposed to row) based.',
            util_meta.snippet_get_permissions (
                a_ddl_schema => l_ddl_schema,
                a_object_type => l_table_noun,
                a_action => 'select',
                a_id_param => 'null' ),
            '',
            util_meta.indent (1) || 'RETURN QUERY',
            util_meta.indent (2) || 'WITH base AS (',
            util_meta.indent (3) || 'SELECT ' || array_to_string ( l_search_cols, ',' || util_meta.new_line () || util_meta.indent (5) ),
            util_meta.indent (4) || 'FROM ' || l_full_view_name,
            util_meta.indent (4) || 'WHERE l_has_permission',
            util_meta.indent (2) || '),',
            l_found_cte,
            l_select || ' ) ;' ) ;

    END IF ;

    l_result := concat_ws ( util_meta.new_line (),
        l_result,
        util_meta.snippet_function_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_comment => l_doc_item,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_datatypes => l_param_types ) ) ;

    RETURN l_result ;

END ;
$$ ;
