CREATE OR REPLACE FUNCTION util_meta.mk_priv_update_procedure (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_cast_booleans_as text DEFAULT NULL,
    a_insert_audit_columns text DEFAULT NULL,
    a_update_audit_columns text DEFAULT NULL,
    a_owner text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_priv_update_procedure generates a draft "private" update procedure for a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |

Note that this should work for dt and rt table types

Note that the generated procedure has no permissions check and is not intended
to be called from outside the database

*/
DECLARE

    r record ;

    l_assertions text[] ;
    l_dc text ;
    l_ddl_schema text ;
    l_distinct_cols text[] ;
    l_false_val text ;
    l_local_checks text[] ;
    l_log_err_line text ;
    l_pk_cols text[] ;
    l_pk_params text[] ;
    l_proc_name text ;
    l_result text ;
    l_set_cols text[] ;
    l_table_noun text ;
    l_true_val text ;
    l_value_param text ;
    l_where_cols text[] ;

    l_local_vars util_meta.ut_parameters ;
    l_calling_params util_meta.ut_parameters ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta._is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    -- Check that util_log schema exists
    IF util_meta._is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
        l_log_err_line := util_meta._indent ( 2 ) || 'call util_log.log_exception ( a_err ) ;' ;
    END IF ;

    l_assertions := array_append (
        l_assertions,
        'User permissions have already been checked and do not require further checking' ) ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta._table_noun ( a_object_name, l_ddl_schema ) ;
    l_proc_name := 'priv_update_' || util_meta._to_singular ( l_table_noun ) ;

    l_local_vars := util_meta._append_parameter (
        a_parameters => l_local_vars,
        a_name => 'l_acting_user_id',
        a_datatype => 'integer' ) ;

    ----------------------------------------------------------------------------
    FOR r IN (
        SELECT boolean_type,
                true_val,
                false_val
            FROM util_meta._boolean_casting ( a_cast_booleans_as ) ) LOOP

        l_true_val := r.true_val ;
        l_false_val := r.false_val ;

        IF coalesce ( l_true_val, '' ) = '' OR coalesce ( l_false_val, '' ) = '' THEN

            RETURN 'ERROR: Could not resolve true/false values' ;

        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- ASSERTION: There will be a dt_user table of some sort and this table
    -- will have a single-column primary key of an "id" variety, therefore there
    -- will also be a resolve_user_id function of some sort.

    l_local_checks := array_append ( l_local_checks, util_meta._snip_resolve_user_id () ) ;

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
            FROM util_meta._proc_parameters (
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
            l_pk_cols := array_append ( l_pk_cols, r.column_name ) ;
            l_pk_params := array_append ( l_pk_params, r.param_name ) ;
        END IF ;

        IF r.param_name IS NOT NULL THEN

            l_calling_params := util_meta._append_parameter (
                a_parameters => l_calling_params,
                a_name => r.param_name,
                a_direction => r.param_direction,
                a_datatype => r.param_data_type,
                a_description => r.comments ) ;

        END IF ;

        IF r.ref_param_name IS NOT NULL AND NOT r.is_audit_col THEN

            l_calling_params := util_meta._append_parameter (
                a_parameters => l_calling_params,
                a_name => r.ref_param_name,
                a_direction => r.param_direction,
                a_datatype => r.ref_data_type,
                a_description => r.ref_param_comments ) ;

        END IF ;

        IF r.local_param_name IS NOT NULL AND r.local_param_name <> 'l_acting_user_id' THEN

            l_local_vars := util_meta._append_parameter (
                a_parameters => l_local_vars,
                a_name => r.local_param_name,
                a_datatype => r.column_data_type ) ;

            IF r.column_data_type = 'boolean' THEN

                IF r.column_default = 'false' THEN
                    l_local_checks := array_append (
                        l_local_checks,
                        util_meta._indent ( 1 )
                            || r.local_param_name
                            || ' := coalesce ( '
                            || r.param_name || ', '
                            || l_false_val
                            || ' ) = '
                            || l_true_val
                            || ' ;' ) ;
                ELSE
                    l_local_checks := array_append (
                        l_local_checks,
                        util_meta._indent ( 1 )
                            || r.local_param_name
                            || ' := coalesce ( '
                            || r.param_name || ', '
                            || l_true_val
                            || ' ) = '
                            || l_true_val
                            || ' ;' ) ;
                END IF ;

            ELSE

                IF r.is_nullable THEN
                    -- If the column is nullable then we need to check that parameters were specified as
                    -- part of ensuring that the lookup was sucessful

                    l_local_checks := array_append (
                        l_local_checks,
                        concat_ws (
                            util_meta._new_line (),
                            util_meta._indent ( 1 )
                                || concat_ws (
                                    ' ',
                                    r.local_param_name,
                                    ':=',
                                    r.resolve_id_function,
                                    '(',
                                    concat_ws ( ', ', r.param_name, r.ref_param_name ),
                                    ')',
                                    ';' ),
                            util_meta._indent ( 1 )
                                || concat_ws (
                                    ' ',
                                    'IF',
                                    r.local_param_name,
                                    'IS NULL AND (',
                                    r.param_name,
                                    'IS NOT NULL OR',
                                    r.ref_param_name,
                                    'IS NOT NULL ) THEN' ),
                            util_meta._indent ( 2 )
                                || concat_ws (
                                    ' ',
                                    'a_err := ''Invalid',
                                    r.error_tag,
                                    'specified'' ;' ),
                            l_log_err_line,
                            util_meta._indent ( 2 ) || 'RETURN ;',
                            util_meta._indent ( 1 ) || 'END IF ;' ) ) ;

                ELSE
                    -- If the column is NOT nullable then we only need to check that the lookup was successful
                    l_local_checks := array_append (
                        l_local_checks,
                        concat_ws (
                            util_meta._new_line (),
                            util_meta._indent ( 1 )
                                || concat_ws (
                                    ' ',
                                    r.local_param_name,
                                    ':=',
                                    r.resolve_id_function,
                                    '(',
                                    concat_ws ( ', ', r.param_name, r.ref_param_name ),
                                    ')',
                                    ';' ),
                            util_meta._indent ( 1 ) || concat_ws (
                                ' ',
                                'IF',
                                r.local_param_name,
                                'IS NULL THEN' ),
                            util_meta._indent ( 2 )
                                || concat_ws (
                                    ' ',
                                    'a_err := ''No, or invalid,',
                                    r.error_tag,
                                    'specified'' ;' ),
                            l_log_err_line,
                            util_meta._indent ( 2 ) || 'RETURN ;',
                            util_meta._indent ( 1 ) || 'END IF ;' ) ) ;

                END IF ;

            END IF ;

        END IF ;

        ------------------------------------------------------------------------
        -- Update statement related
        IF r.column_name IS NOT NULL THEN

            -- we don't want to update insert audit data
            IF r.is_audit_col AND r.audit_action = 'insert' THEN
                CONTINUE ;
            END IF ;

            l_value_param := coalesce ( r.local_param_name, r.param_name ) ;

            IF r.is_pk THEN
                l_where_cols := array_append (
                    l_where_cols,
                    concat_ws (
                        ' ',
                        'o.' || r.column_name,
                        '=',
                        l_value_param ) ) ;

            ELSIF r.is_audit_col THEN

                IF r.is_audit_tmsp_col THEN
                    l_set_cols := array_append ( l_set_cols, concat_ws (
                            ' ',
                            r.column_name,
                            '=',
                            'now ()' ) ) ;
                ELSE
                    l_set_cols := array_append ( l_set_cols, concat_ws (
                            ' ',
                            r.column_name,
                            '=',
                            l_value_param ) ) ;
                END IF ;

            ELSE
                l_set_cols := array_append ( l_set_cols, concat_ws (
                        ' ',
                        r.column_name,
                        '=',
                        l_value_param ) ) ;
                l_distinct_cols := array_append (
                    l_distinct_cols,
                    concat_ws (
                        ' ',
                        'o.' || r.column_name,
                        'IS DISTINCT FROM',
                        l_value_param ) ) ;

            END IF ;

        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    IF array_length ( l_pk_cols, 1 ) = 0 THEN
        RETURN 'ERROR: Table must have a primary key' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        util_meta._snip_procedure_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_procedure_purpose => 'performs an update on ' || a_object_name,
            a_language => 'plpgsql',
            a_assertions => l_assertions,
            a_calling_parameters => l_calling_params,
            a_variables => l_local_vars ),
        util_meta._snip_log_params ( a_parameters => l_calling_params ) ) ;

    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        '',
        array_to_string ( l_local_checks, util_meta._new_line ( 2 ) ),
        '',
        util_meta._indent ( 1 ) || '-- TODO review existing/add additional checks and lookups' ) ;

    /*

    TODO If there is a boolean column named "is_default" and the new value is true then we
    might want code that will conditionally set the current default row to false.


l_parent_id_param

    l_local_vars := util_meta._append_parameter (
        a_parameters => l_local_vars,
        a_name => r.local_param_name,
        a_datatype => r.param_data_type ) ;




    If there is a parent_id, is the default per parent?

        '''
        IF l_is_default THEN

            UPDATE schema.table
                SET is_default = false,
                    updated_tmsp = now (),
                    user_id_updated = l_acting_user_id
                WHERE is_default
                    AND id IS DISTINCT FROM a_id ;

        END IF ;
        '''

    */

    ----------------------------------------------------------------------------
    -- Add the update
    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        '',
        util_meta._indent ( 1 ) || 'UPDATE ' || a_object_schema || '.' || a_object_name || ' o',
        util_meta._indent ( 2 )
            || 'SET '
            || array_to_string ( l_set_cols, ',' || util_meta._new_line () || util_meta._indent ( 3 ) ),
        util_meta._indent ( 2 )
            || 'WHERE '
            || array_to_string ( l_where_cols, util_meta._new_line () || util_meta._indent ( 3 ) || 'AND ' ) ) ;

    IF array_length ( l_distinct_cols, 1 ) > 0 THEN
        l_dc := ' ( '
            || array_to_string ( l_distinct_cols, util_meta._new_line () || util_meta._indent ( 4 ) || 'OR ' )
            || ' )' ;
    END IF ;

    IF l_dc IS NOT NULL THEN

        l_result := concat_ws ( util_meta._new_line (), l_result, util_meta._indent ( 3 ) || 'AND' || l_dc || ' ;' ) ;

    ELSE

        l_result := concat_ws ( ' ', l_result, ';' ) ;

    END IF ;

    --------------------------------------------------------------------
    -- Wrap it up
    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        util_meta._snip_procedure_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_comment => 'performs an update on ' || a_object_name,
            a_owner => a_owner,
            a_calling_parameters => l_calling_params ) ) ;

    RETURN util_meta._cleanup_whitespace ( l_result ) ;

END ;
$$ ;
