CREATE OR REPLACE FUNCTION util_meta.mk_update_procedure (
    a_object_schema text default null,
    a_object_name text default null,
    a_ddl_schema text default null,
    a_cast_booleans_as text default null,
    a_insert_audit_columns text default null,
    a_update_audit_columns text default null,
    a_owner text default null,
    a_grantees text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function mk_update_procedure generates a draft "public" update procedure for a table

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

Note that this should work for dt and rt table types

*/
DECLARE

    r record ;

    l_chk text ;
    l_chk_where text[] ;
    l_ddl_schema text ;
    l_pk_params text[] ;
    l_proc_args text[] ;
    l_proc_name text ;
    l_result text ;
    l_table_noun text ;

    l_local_vars util_meta.ut_parameters ;
    l_calling_params util_meta.ut_parameters ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta.table_noun ( a_object_name, l_ddl_schema ) ;
    l_proc_name := 'update_' || l_table_noun ;

    l_local_vars := util_meta.append_parameter (
        a_parameters => l_local_vars,
        a_name => 'r',
        a_datatype => 'record' ) ;

    l_local_vars := util_meta.append_parameter (
        a_parameters => l_local_vars,
        a_name => 'l_has_permission',
        a_datatype => 'boolean' ) ;

    --------------------------------------------------------------------
    -- Determine the calling parameters block, signature, etc.
    FOR r IN (
        SELECT schema_name,
                object_name,
                column_name,
                column_data_type,
                column_default,
                ordinal_position,
                is_pk,
                is_nk,
                is_nullable,
                is_audit_col,
                audit_action,
                is_audit_tmsp_col,
                is_audit_user_col,
                param_name,
                param_direction,
                param_data_type,
                ref_param_name,
                ref_data_type,
                local_param_name,
                resolve_id_function,
                error_tag,
                comments,
                ref_param_comments
            FROM util_meta.proc_parameters (
                a_action => 'update',
                a_object_schema => a_object_schema,
                a_object_name => a_object_name,
                a_ddl_schema => l_ddl_schema,
                a_cast_booleans_as => a_cast_booleans_as,
                a_insert_audit_columns => a_insert_audit_columns,
                a_update_audit_columns => a_update_audit_columns )
            ORDER BY ordinal_position ) LOOP

        ------------------------------------------------------------------------
        -- Calling arguments and parameters related
        IF r.is_pk THEN
            l_chk_where := array_append ( l_chk_where, concat_ws ( ' ', r.column_name, '=', r.param_name ) ) ;
            l_pk_params := array_append ( l_pk_params, r.param_name ) ;
        END IF ;

        IF r.param_name IS NOT NULL THEN

            l_calling_params := util_meta.append_parameter (
                a_parameters => l_calling_params,
                a_name => r.param_name,
                a_direction => r.param_direction,
                a_datatype => r.param_data_type,
                a_comment => r.comments ) ;

        END IF ;

        IF r.ref_param_name IS NOT NULL AND NOT r.is_audit_col THEN

            l_calling_params := util_meta.append_parameter (
                a_parameters => l_calling_params,
                a_name => r.ref_param_name,
                a_direction => r.param_direction,
                a_datatype => r.ref_data_type,
                a_comment => r.ref_param_comments ) ;

        END IF ;


    END LOOP ;

    ----------------------------------------------------------------------------
    -- Create the permissions check for the update.
    -- ASSERT: the table being updated has a single, integer, primary key column
    l_chk := concat_ws ( util_meta.new_line (),
        util_meta.indent (1) || 'FOR r IN (',
        util_meta.indent (2) || 'SELECT ' || quote_literal ( l_pk_params[1] ) || ' AS param',
        util_meta.indent (3) || 'FROM ' || a_object_schema || '.' || a_object_name,
        util_meta.indent (3) || 'WHERE ' || array_to_string ( l_chk_where, util_meta.new_line () || util_meta.indent (4) || 'AND ' ) || ' ) LOOP',
        '',
        util_meta.snippet_get_permissions (
            a_indents => 2,
            a_action => 'update',
            a_ddl_schema => a_ddl_schema,
            a_object_type => l_table_noun,
            a_id_param => 'r.param' ),
        '',
        util_meta.indent (1) || 'END LOOP ;',
        '',
        util_meta.indent (1) || 'IF NOT l_has_permission THEN',
        util_meta.indent (2) || 'a_err := ''Insufficient privileges or the ''' || l_table_noun || ' does not exist'' ;' ) ;

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
        l_result,
        util_meta.snippet_procedure_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_procedure_purpose => 'performs an update on ' || a_object_name,
            a_language => 'plpgsql',
            a_calling_parameters => l_calling_params,
            a_variables => l_local_vars ),
        util_meta.snippet_log_params (
            a_parameters => l_calling_params ),
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
            a_calling_parameters => l_calling_params ) ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
