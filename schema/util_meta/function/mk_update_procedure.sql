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

    l_ddl_schema text ;

    l_local_var_names text[] ;
    l_local_types text[] ;
    l_log_err_line text ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;

    l_pk_params text[] ;
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
    -- Check that util_log schema exists
    IF util_meta.is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
        l_log_err_line := util_meta.indent (2) || 'call util_log.log_exception ( a_err ) ;' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta.table_noun ( a_object_name, l_ddl_schema ) ;
    l_proc_name := 'update_' || l_table_noun ;

    l_local_var_names := array_append ( l_local_var_names, 'l_has_permission' ) ;
    l_local_types := array_append ( l_local_types, 'boolean' ) ;

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
            l_pk_params := array_append ( l_pk_params, r.param_name ) ;
        END IF ;

        IF r.param_name IS NOT NULL THEN

            l_proc_args := array_append ( l_proc_args, concat_ws ( ' ', r.param_name, '=>', r.param_name ) ) ;

            l_param_names := array_append ( l_param_names, r.param_name ) ;
            l_param_directions := array_append ( l_param_directions, r.param_direction ) ;
            l_param_types := array_append ( l_param_types, r.param_data_type ) ;
            l_param_comments := array_append ( l_param_comments, r.comments ) ;

        END IF ;

        IF r.ref_param_name IS NOT NULL AND NOT r.is_audit_col THEN

            l_proc_args := array_append ( l_proc_args, concat_ws ( ' ', r.ref_param_name, '=>', r.ref_param_name ) ) ;

            l_param_names := array_append ( l_param_names, r.ref_param_name ) ;
            l_param_directions := array_append ( l_param_directions, r.param_direction ) ;
            l_param_types := array_append ( l_param_types, r.ref_data_type ) ;
            l_param_comments := array_append ( l_param_comments, r.ref_param_comments ) ;

        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        l_result,
        util_meta.snippet_procedure_frontmatter (
            a_object_name => a_object_name,
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_procedure_purpose => 'performs an update on ' || a_object_name,
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
        util_meta.snippet_permissions_check (
            a_action => 'update',
            a_ddl_schema => l_ddl_schema,
            a_object_type => l_table_noun,
            a_id_param => l_pk_params[1] ),
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

    RETURN l_result ;

END ;
$$ ;
