CREATE OR REPLACE FUNCTION util_meta.mk_delete_procedure (
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
Function mk_delete_procedure generates a draft "public" delete procedure for a table

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

Note that this should work for dt and rt table types

*/
DECLARE

    r record ;

    l_ddl_schema text ;
    l_local_var_names text[] ;
    l_local_types text[] ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;
    l_chk text ;
    l_chk_where text[] ;
    l_pk_params text[] ;
    --l_pk_cols text[] ;
    l_proc_args text[] ;
    l_proc_name text ;
    l_result text ;
    l_table_noun text ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta.table_noun ( a_object_name, l_ddl_schema ) ;
    l_proc_name := 'delete_' || l_table_noun ;

    l_local_var_names := array_append ( l_local_var_names, 'r' ) ;
    l_local_types := array_append ( l_local_types, 'record' ) ;
    l_local_var_names := array_append ( l_local_var_names, 'l_has_permission' ) ;
    l_local_types := array_append ( l_local_types, 'boolean' ) ;

    ------------------------------------------------------------------------
    -- Determine the calling parameters block, signature, etc.
    FOR r IN (
        SELECT schema_name,
                object_name,
                column_name,
                column_data_type,
                ordinal_position,
                is_pk,
                is_nk,
                param_name,
                param_direction,
                param_data_type,
                comments
            FROM util_meta.proc_parameters (
                a_action => 'delete',
                a_object_schema => a_object_schema,
                a_object_name => a_object_name,
                a_ddl_schema => l_ddl_schema )
            WHERE is_pk
                OR param_name in ( 'a_err', 'a_user' )
            ORDER BY ordinal_position ) LOOP

        IF r.is_pk THEN
            l_chk_where := array_append ( l_chk_where, concat_ws ( ' ', r.column_name, '=', r.param_name ) ) ;
            l_pk_params := array_append ( l_pk_params, r.param_name ) ;
            --l_pk_cols := array_append ( l_pk_cols, r.column_name ) ;
            --l_local_var_names := array_append ( l_local_var_names, 'l_' || r.column_name ) ;
            --l_local_types := array_append ( l_local_types, r.param_data_type ) ;
        END IF ;

        l_proc_args := array_append ( l_proc_args, concat_ws ( ' ', r.param_name, '=>', r.param_name ) ) ;

        l_param_names := array_append ( l_param_names, r.param_name ) ;
        l_param_directions := array_append ( l_param_directions, r.param_direction ) ;
        l_param_types := array_append ( l_param_types, r.param_data_type ) ;
        l_param_comments := array_append ( l_param_comments, r.comments ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    IF array_length ( l_pk_params, 1 ) = 0 THEN
        RETURN 'ERROR: Table must have a primary key' ;
    END IF ;

    ----------------------------------------------------------------------------
    -- Create the permissions check for the delete.
    -- ASSERT: the table being deleted from has a single, integer, primary key column
    l_chk := concat_ws ( util_meta.new_line (),
        util_meta.indent (1) || 'FOR r IN (',
        util_meta.indent (2) || 'SELECT ' || quote_literal ( l_pk_params[1] ) || ' AS param',
        util_meta.indent (3) || 'FROM ' || a_object_schema || '.' || a_object_name,
        util_meta.indent (3) || 'WHERE ' || array_to_string ( l_chk_where, util_meta.new_line () || util_meta.indent (4) || 'AND ' ) || ' ) LOOP',
        '',
        util_meta.snippet_get_permissions (
            a_indents => 2,
            a_action => 'delete',
            a_ddl_schema => a_ddl_schema,
            a_object_type => l_table_noun,
            a_id_param => 'r.param' ),
        '',
        util_meta.indent (1) || 'END LOOP ;',
        '',
        util_meta.indent (1) || 'IF NOT l_has_permission THEN',
        util_meta.indent (2) || 'a_err := ''Insufficient privileges or the ''' || l_table_noun || ' does not exist or has already been deleted'' ;' ) ;

        IF util_meta.is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
            l_chk := concat_ws ( util_meta.new_line (),
                l_chk,
                util_meta.indent (2) || 'call util_log.log_exception ( a_err ) ;' ) ;
        END IF ;

        l_chk := concat_ws ( util_meta.new_line (),
            l_chk,
            util_meta.indent (2) || 'RETURN ;',
            util_meta.indent (1) || 'END IF ;' ) ;

    ----------------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        util_meta.snippet_procedure_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_procedure_purpose => 'performs a delete on ' || a_object_name,
            a_language => 'plpgsql',
            a_param_names => l_param_names,
            a_param_directions => l_param_directions,
            a_param_datatypes => l_param_types,
            a_param_comments => l_param_comments,
            a_local_var_names => l_local_var_names,
            a_local_var_datatypes => l_local_types ),
        util_meta.snippet_log_params (
            a_param_names => l_param_names,
            a_datatypes => l_param_types ),
        '',
        l_chk,
        '',
        util_meta.indent (1) || 'call ' || l_ddl_schema || '.priv_' || l_proc_name || ' (',
        util_meta.indent (2) || array_to_string ( l_proc_args, ',' || util_meta.new_line () || util_meta.indent (2) ) || ' ) ;',
        util_meta.snippet_procedure_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_comment => null::text,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_datatypes => l_param_types ) ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
