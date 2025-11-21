CREATE OR REPLACE FUNCTION util_meta.mk_insert_procedure (
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
Function mk_insert_procedure generates a draft "public" insert procedure for a table

| Parameter                      | In/Out | Datatype   | Description                                        |
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
    l_parent_id_param text ;
    l_parent_noun text ;

    l_pk_cols text[] ;
    l_pk_params text[] ;
    l_proc_args text[] ;
    l_proc_name text ;
    l_result text ;
    l_table_noun text ;
    l_id_param text ;

    l_local_vars util_meta.ut_parameters ;
    l_calling_params util_meta.ut_parameters ;
    l_private_proc util_meta.ut_proc ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta.table_noun ( a_object_name, l_ddl_schema ) ;
    l_proc_name := 'insert_' || l_table_noun ;

    l_local_vars := util_meta.append_parameter (
        a_parameters => l_local_vars,
        a_name => 'l_has_permission',
        a_datatype => 'boolean' ) ;

    ------------------------------------------------------------------------
    -- Determine the private procedure to call.
    l_private_proc := util_meta.guess_private_proc (
        a_proc_schema => l_ddl_schema,
        a_proc_object => a_object_name,
        a_proc_action => 'insert' ) ;

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
                    a_action => 'insert',
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
            l_pk_cols := array_append ( l_pk_cols, r.column_name ) ;
            l_pk_params := array_append ( l_pk_params, r.param_name ) ;
        END IF ;

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

            l_proc_args := array_append ( l_proc_args, concat_ws (
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

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Determine if there is a single FK relationship to a dt_ table and,
    -- if so, then determine the parent type and parameter name for that so
    -- it can be used for the insert permissions check
    FOR r IN (
        SELECT count (*) AS kount
            FROM util_meta.foreign_keys
            WHERE schema_name = a_object_schema
                AND table_name = a_object_name
                AND ref_table_name ~ '^dt_' ) LOOP

        IF r.kount = 1 THEN

            FOR r IN (
                SELECT column_names,
                        ref_schema_name,
                        ref_table_name,
                        ref_full_table_name,
                        ref_column_names
                    FROM util_meta.foreign_keys
                    WHERE schema_name = a_object_schema
                        AND table_name = a_object_name
                        AND ref_table_name ~ '^dt_'
                        AND column_names !~ ',' ) LOOP

                l_parent_noun := regexp_replace (
                    regexp_replace ( r.ref_table_name, '^d[tv]_', '' ),
                    '^' || l_ddl_schema || '_',
                    '' ) ;
                l_parent_id_param := 'l_' || r.column_names ;

            END LOOP ;

        END IF ;

    END LOOP ;

    IF cardinality ( l_pk_params ) > 0 AND l_pk_params[1] IS NOT NULL THEN
        l_id_param := l_pk_params[1] ;
    ELSE
        l_id_param := 'null::integer' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta.new_line (),
        l_result,
        util_meta.snippet_procedure_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_procedure_purpose => 'performs an insert on ' || a_object_name,
            a_language => 'plpgsql',
            a_calling_parameters => l_calling_params,
            a_variables => l_local_vars ),
        util_meta.snippet_log_params ( a_parameters => l_calling_params ),
        '',
        util_meta.indent ( 1 )
            || '----------------------------------------------------------------------------------------------------------',
        util_meta.indent ( 1 )
            || '-- TODO: determine if the parent type and ID is needed for can_do and, if so, what the ID of the parent is',
        util_meta.snippet_permissions_check (
            a_action => 'insert',
            a_ddl_schema => l_ddl_schema,
            a_object_type => l_table_noun,
            a_id_param => l_id_param,
            a_parent_object_type => l_parent_noun,
            a_parent_id_param => l_parent_id_param ),
        '',
        util_meta.indent ( 1 ) || 'call ' || l_private_proc.full_name || ' (',
        util_meta.indent ( 2 )
            || array_to_string ( l_proc_args, ',' || util_meta.new_line () || util_meta.indent ( 2 ) )
            || ' ) ;',
        util_meta.snippet_procedure_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_comment => 'performs an insert on ' || a_object_name,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_calling_parameters => l_calling_params ) ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
