CREATE OR REPLACE FUNCTION util_meta.mk_list_function (
    a_object_schema text default null,
    a_object_name text default null,
    a_parent_table_schema text default null,
    a_parent_table_name text default null,
    a_ddl_schema text default null,
    a_exclude_binary_data boolean default null,
    a_audit_columns text default null,
    a_owner text default null,
    a_grantees text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function mk_list_function generates a draft "list entries that are a children of the specified parent" function for a table.

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_parent_table_schema          | in     | text       | The (name of the) schema that contains the parent table   |
| a_parent_table_name            | in     | text       | The (name of the) parent table                     |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_exclude_binary_data          | in     | boolean    | Indicates if binary (bytea, jsonb) data is to be excluded from the result-set (default is to include binary data) |
| a_audit_columns                | in     | text       | The (optional) csv list of audit columns (user created, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

If the parent table is not specified then the function will attempt to determine a parent

ASSERTIONS

 * In the schema that the list function will be created in there will be:

   1. a view for the table (mk_view)

   2. a function for resolving the ID of the parent table (mk_resolve_id_function)

TODO

 * Explore the feasibility of implementing the query for row-based permissions
 (currently uses permissions for parent table tow)

*/
DECLARE

    r record ;

    l_child_column text ;
    l_ddl_schema text ;
    l_doc_item text ;
    l_full_view_name text ;
    l_func_name text ;
    l_local_var_names text[] ;
    l_local_types text[] ;
    l_local_parent_param text ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;
    l_parent_noun text ;
    l_parent_param text ;
    l_parent_schema text ;
    l_parent_column text ;
    l_parent_table text ;
    l_resolve_id_func text ;
    l_resolve_id_params text[] ;
    l_result text ;
    l_table_noun text ;
    l_view_name text ;
    l_where_clause text ;
    l_exclude_binary_data boolean ;
    l_select_cols text[] ;
    l_select text ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta.table_noun ( a_object_name, l_ddl_schema ) ;

    l_func_name := 'list_' || l_table_noun || 's' ;
    l_view_name := regexp_replace ( a_object_name, '^([drs])t_', '\1v_' ) ;
    l_full_view_name := concat_ws ( '.', l_ddl_schema, l_view_name ) ;

    --------------------------------------------------------------------
    -- Ensure that the view is valid
    IF NOT util_meta.is_valid_object ( l_ddl_schema, l_view_name, 'view' ) THEN
        RETURN 'ERROR: required view (' || l_full_view_name || ') does not exist' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_exclude_binary_data := coalesce ( a_exclude_binary_data, false ) ;

    l_local_var_names := array_append ( l_local_var_names, 'l_has_permission' ) ;
    l_local_types := array_append ( l_local_types, 'boolean' ) ;

    ----------------------------------------------------------------------------
    -- Ensure that there is one, and only one, parent dt_ table (otherwise, how can we know which one to use?)
    FOR r IN (
        WITH audit_cols AS (
            SELECT trim ( regexp_split_to_table ( a_audit_columns, ',' ) ) AS column_name
        )
        SELECT count (*) AS kount
            FROM util_meta.foreign_keys fks
            LEFT JOIN audit_cols ac
                ON ( ac.column_name = fks.column_names )
            WHERE fks.schema_name = a_object_schema
                AND fks.table_name = a_object_name
                AND fks.ref_table_name ~ '^dt_'
                AND fks.column_names NOT LIKE '%,%'
                AND ac.column_name IS NULL
                AND ( ( a_parent_table_schema IS NOT NULL
                        AND fks.ref_schema_name = a_parent_table_schema
                        AND fks.ref_table_name = a_parent_table_name )
                    OR ( a_parent_table_schema IS NULL ) ) ) LOOP

        IF r.kount = 0 THEN
            RETURN 'ERROR: no primary parent found' ;
        END IF ;

        IF r.kount > 1 THEN
            RETURN 'ERROR: too many primary parents found' ;
        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Obtain the primary parent for the table
    FOR r IN (
        WITH audit_cols AS (
            SELECT trim ( regexp_split_to_table ( a_audit_columns, ',' ) ) AS column_name
        )
        SELECT fks.schema_name,
                fks.table_name,
                fks.column_names,
                fks.ref_schema_name,
                fks.ref_table_name,
                fks.ref_column_names
            FROM util_meta.foreign_keys fks
            LEFT JOIN audit_cols ac
                ON ( ac.column_name = fks.column_names )
            WHERE fks.schema_name = a_object_schema
                AND fks.table_name = a_object_name
                AND fks.ref_table_name ~ '^dt_'
                AND fks.column_names NOT LIKE '%,%'
                AND ac.column_name IS NULL
                AND ( ( a_parent_table_schema IS NOT NULL
                        AND fks.ref_schema_name = a_parent_table_schema
                        AND fks.ref_table_name = a_parent_table_name )
                    OR ( a_parent_table_schema IS NULL ) ) ) LOOP

        l_parent_schema := r.ref_schema_name ;
        l_parent_table := r.ref_table_name ;
        l_parent_column := r.ref_column_names ;
        l_child_column := r.column_names ;

        l_local_parent_param := 'l_' || r.column_names ;
        l_parent_param := 'a_' || r.ref_column_names ;

        l_parent_noun := regexp_replace ( regexp_replace ( l_parent_table, '^d[tv]_', '' ), '^' || l_ddl_schema || '_', '' ) ;

        l_resolve_id_func := l_ddl_schema ||'.' || concat_ws ( '_', 'resolve', l_parent_noun, 'id' ) ;

        l_doc_item := 'Returns the list of '
            || replace ( l_table_noun, '_', ' ' ) || ' entries for the specified '
            || replace ( l_parent_noun, '_', ' ' ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Obtain the parameters for resolving the parent
    FOR r IN (
        SELECT schema_name,
                object_name,
                column_name,
                data_type,
                is_pk,
                is_nk,
                'a_' || column_name AS param_name,
                trim ( coalesce ( comments, 'TBD' ) ) AS comments
            FROM util_meta.columns
            WHERE schema_name = l_parent_schema
                AND object_name = l_parent_table
                AND column_name = l_parent_column
                AND ( is_pk
                    OR is_nk )
            ORDER BY ordinal_position ) LOOP

        l_param_names := array_append ( l_param_names, r.param_name ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, r.data_type ) ;
        l_param_comments := array_append ( l_param_comments, r.comments ) ;

        l_resolve_id_params := array_append ( l_resolve_id_params, r.param_name ) ;

    END LOOP ;

    IF array_length ( l_resolve_id_params, 1 ) = 0 THEN
        RETURN 'ERROR: could not resolve PK parameter' ;
    ELSIF array_length ( l_resolve_id_params, 1 ) > 1 THEN
        l_local_var_names := array_append ( l_local_var_names, l_local_parent_param ) ;
        l_local_types := array_append ( l_local_types, l_parent_data_type ) ;
    END IF ;

    ----------------------------------------------------------------------------
    l_param_names := array_append ( l_param_names, 'a_user' ) ;
    l_param_directions := array_append ( l_param_directions, 'in' ) ;
    l_param_types := array_append ( l_param_types, 'text' ) ;
    l_param_comments := array_append ( l_param_comments, 'The ID or username of the user requesting the list' ) ;

    ----------------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        l_result,
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
            a_var_names => l_local_var_names,
            a_var_datatypes => l_local_types ),
        '',
        util_meta.indent (1) || '-- TODO: review this as different applications may have different permissions models.',
        util_meta.indent (1) || '-- As written, this asserts that the permissions model is table (as opposed to row) based.' ) ;

    ----------------------------------------------------------------------------
    IF array_length ( l_resolve_id_params, 1 ) = 1 THEN

        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            util_meta.snippet_get_permissions (
                a_action => 'select',
                a_ddl_schema => l_ddl_schema,
                a_object_type => l_parent_noun,
                a_id_param => l_parent_param ) ) ;

        l_where_clause := concat_ws ( ' ',  l_child_column, '=', l_parent_param ) ;

    ELSIF array_length ( l_resolve_id_params, 1 ) > 1 THEN

        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            '',
            util_meta.snippet_resolve_id (
                a_id_param => l_local_parent_param,
                a_function_schema => l_ddl_schema,
                a_function_name => l_resolve_id_func,
                a_resolve_id_params => l_resolve_id_params ),
            util_meta.snippet_get_permissions (
                a_action => 'select',
                a_ddl_schema => l_ddl_schema,
                a_object_type => l_parent_noun,
                a_id_param => l_local_parent_param ) ) ;

        l_where_clause := concat_ws ( ' ',  l_child_column, '=', l_local_parent_param ) ;

    END IF ;

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
                l_select_cols := array_append ( l_select_cols, r.column_name ) ;
            END IF ;

        END LOOP ;

        l_select := util_meta.indent (2) || 'SELECT ' || array_to_string ( l_select_cols, ',' || util_meta.new_line () || util_meta.indent (4) ) ;

    ELSE

        l_select := util_meta.indent (2) || 'SELECT *' ;

    END IF ;

    ----------------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        l_result,
        '',
        util_meta.indent (1) || 'RETURN QUERY',
        l_select,
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

    RETURN l_result ;

END ;
$$ ;
