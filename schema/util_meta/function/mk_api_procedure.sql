CREATE OR REPLACE FUNCTION util_meta.mk_api_procedure (
    a_action text DEFAULT NULL,
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_cast_booleans_as text DEFAULT NULL,
    a_insert_audit_columns text DEFAULT NULL,
    a_update_audit_columns text DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_api_procedure generates a draft API procedure for a DML action on a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_action                       | in     | text       | The action that the generated procedure should perform {insert, update, upsert, delete} |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the procedure |

Generates the API code that checks permissions and wraps the appropriate
"private" procedure that does the actual work.

ASSERTIONS:

1. The table to create the procedure for has a single, integer, primary key column
2. The associated private procedure has already been created in the database

*/

DECLARE

    r record ;
    l_calling_params util_meta.ut_parameters ;
    l_local_vars util_meta.ut_parameters ;
    l_parent util_meta.ut_parent_table ;
    l_private_proc util_meta.ut_object ;
    l_procedure_type text := 'procedure' ;

    l_chk text ;
    l_ddl_schema text ;
    l_full_table_name text ;
    l_id_param text ;
    l_pk_cols text[] ;
    l_pk_params text[] ;
    l_proc_name text ;
    l_purpose text ;
    l_result text ;
    l_table_noun text ;
    l_log_line text ;
    l_err_line text ;
    l_parent_id_param text ;
    l_perm_chk text ;
    l_proc_args text[] ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified action is valid
    IF a_action NOT IN ( 'insert', 'update', 'upsert', 'delete' ) THEN
        RETURN 'ERROR: invalid action specified. Valid actions are {insert, update, upsert, and delete}' ;
    END IF ;

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object specified' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta.table_noun ( a_object_name, l_ddl_schema ) ;
    l_proc_name := concat_ws ( '_', a_action, l_table_noun ) ;
    l_full_table_name := concat_ws ( '.', a_object_schema, a_object_name ) ;

    l_purpose := 'performs ' || a_action || ' actions on ' || l_full_table_name ;

    ------------------------------------------------------------------------
    -- Determine the private procedure to call.
    l_private_proc := util_meta.find_private_proc (
        a_proc_schema => l_ddl_schema,
        a_proc_name => l_proc_name ) ;

    ----------------------------------------------------------------------------
    IF a_action IN ( 'update', 'upsert', 'delete' ) THEN
        l_local_vars := util_meta.append_parameter (
            a_parameters => l_local_vars,
            a_name => 'r',
            a_datatype => 'record' ) ;
    END IF ;

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
                    a_action => a_action,
                    a_object_schema => a_object_schema,
                    a_object_name => a_object_name,
                    a_ddl_schema => l_ddl_schema,
                    a_cast_booleans_as => a_cast_booleans_as,
                    a_insert_audit_columns => a_insert_audit_columns,
                    a_update_audit_columns => a_update_audit_columns )
            ORDER BY ordinal_position ) LOOP

        IF r.is_pk THEN
            l_pk_cols := array_append ( l_pk_cols, r.column_name ) ;
            l_pk_params := array_append ( l_pk_params, r.param_name ) ;
        END IF ;

        IF a_action = 'delete' THEN

            IF r.is_pk OR r.param_name IN ( 'a_err', 'a_user' ) THEN

                l_proc_args := array_append ( l_proc_args, concat_ws (
                        ' ',
                        r.param_name,
                        '=>',
                        r.param_name ) ) ;

                l_calling_params := util_meta.append_parameter (
                    a_parameters => l_calling_params,
                    a_name => r.param_name,
                    a_direction => r.param_direction,
                    a_datatype => r.param_data_type,
                    a_description => r.comments ) ;

            END IF ;

        ELSE

            IF r.param_name IS NOT NULL THEN

                l_proc_args := array_append ( l_proc_args, concat_ws (
                        ' ',
                        r.param_name,
                        '=>',
                        r.param_name ) ) ;

                l_calling_params := util_meta.append_parameter (
                    a_parameters => l_calling_params,
                    a_name => r.param_name,
                    a_direction => r.param_direction,
                    a_datatype => r.param_data_type,
                    a_description => r.comments ) ;

            END IF ;

            IF r.ref_param_name IS NOT NULL AND NOT r.is_audit_col THEN

                l_proc_args := array_append (
                    l_proc_args,
                    concat_ws (
                        ' ',
                        r.ref_param_name,
                        '=>',
                        r.ref_param_name ) ) ;

                l_calling_params := util_meta.append_parameter (
                    a_parameters => l_calling_params,
                    a_name => r.ref_param_name,
                    a_direction => r.param_direction,
                    a_datatype => r.ref_data_type,
                    a_description => r.ref_param_comments ) ;

            END IF ;

        END IF ;

    END LOOP ;

    IF cardinality ( l_pk_params ) > 0 AND l_pk_params[1] IS NOT NULL THEN
        l_id_param := l_pk_params[1] ;
    END IF ;

    ----------------------------------------------------------------------------
    IF a_action IN ( 'insert', 'upsert' ) THEN
        l_parent := util_meta.get_dt_parent (
            a_object_schema => a_object_schema,
            a_object_name => a_object_name,
            a_ddl_schema => l_ddl_schema ) ;
    END IF ;

    ----------------------------------------------------------------------------
    -- Create the permissions check for the action.
    -- ASSERT: the table being updated has a single, integer, primary key column
    IF a_action IN ( 'insert', 'upsert' ) AND l_parent.parent_noun IS NOT NULL THEN

        l_parent_id_param := 'l_' || l_parent.column_names ;
        l_err_line := 'a_err := ''No, or insufficient, privileges, or the parent ('
            || l_parent.parent_noun
            || ') was not found'' ;' ;
        IF util_meta.is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
            l_log_line := 'call util_log.log_exception ( a_err ) ;' ;
        END IF ;

        l_perm_chk := concat_ws (
            util_meta.new_line (),
            util_meta.indent ( 1 ) || repeat ( '-', 76 ),
            util_meta.indent ( 1 ) || '-- Verify that the parent record exists',
            util_meta.indent ( 1 ) || 'FOR r IN (',
            util_meta.indent ( 2 ) || 'SELECT ' || l_parent.column_names || ' AS param',
            util_meta.indent ( 3 ) || 'FROM ' || l_parent.parent_full_name,
            util_meta.indent ( 3 )
                || 'WHERE '
                || l_parent.parent_column_names
                || ' = a_'
                || l_parent.column_names
                || ' ) LOOP',
            '',
            util_meta.indent ( 2 ) || 'l_parent_id_param := ''l_'' || r.param ;',
            '',
            util_meta.indent ( 1 ) || 'END LOOP ;',
            '',
            util_meta.indent ( 1 ) || 'IF l_parent_id_param IS NULL THEN',
            util_meta.indent ( 2 ) || l_err_line,
            util_meta.indent ( 2 ) || l_log_line,
            util_meta.indent ( 1 ) || 'END IF ;',
            '',
            util_meta.snippet_permissions_check (
                a_indents => 1,
                a_action => a_action,
                a_object_schema => a_object_schema,
                a_object_name => a_object_name,
                a_ddl_schema => l_ddl_schema,
                a_object_type => l_table_noun,
                a_id_param => l_id_param,
                a_parent_object_type => l_parent.parent_noun,
                a_parent_id_param => l_parent_id_param ) ) ;

    ELSE

        l_perm_chk := concat_ws (
            util_meta.new_line (),
            util_meta.indent ( 1 ) || repeat ( '-', 76 ),
            util_meta.snippet_permissions_check (
                a_indents => 0,
                a_action => a_action,
                a_object_schema => a_object_schema,
                a_object_name => a_object_name,
                a_ddl_schema => l_ddl_schema,
                a_object_type => l_table_noun,
                a_id_param => l_id_param ) ) ;

    END IF ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta.new_line (),
        l_result,
        util_meta.snippet_procedure_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_procedure_purpose => l_purpose,
            a_language => 'plpgsql'::text,
            a_calling_parameters => l_calling_params,
            a_variables => l_local_vars ),
        util_meta.snippet_log_params ( a_parameters => l_calling_params ),
        '',
        l_perm_chk,
        '',
        util_meta.indent ( 1 ) || 'call ' || l_private_proc.full_object_name || ' (',
        util_meta.indent ( 2 )
            || array_to_string ( l_proc_args, ',' || util_meta.new_line () || util_meta.indent ( 2 ) )
            || ' ) ;',
        util_meta.snippet_procedure_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_comment => l_purpose,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_calling_parameters => l_calling_params ) ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
