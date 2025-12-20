CREATE OR REPLACE FUNCTION util_meta.mk_priv_delete_procedure (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    --a_insert_audit_columns text default null,
    --a_update_audit_columns text default null,
    a_owner text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_priv_delete_procedure generates a draft "private" delete procedure for a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |

Note that this should work for dt and rt table types

Note that the generated procedure has no permissions check and is not intended
to be called from outside the database

*/
DECLARE

    r record ;

    l_assertions text[] ;
    l_ddl_schema text ;
    l_pk_params text[] ;
    l_proc_name text ;
    l_result text ;
    l_table_noun text ;
    l_where_cols text[] ;
    l_calling_params util_meta.ut_parameters ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta._is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_table_noun := util_meta._table_noun ( a_object_name, l_ddl_schema ) ;
    l_proc_name := 'priv_delete_' || util_meta._to_singular ( l_table_noun ) ;

    l_assertions := array_append (
        l_assertions,
        'User permissions have already been checked and do not require further checking' ) ;

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
            FROM util_meta._proc_parameters (
                    a_action => 'delete',
                    a_object_schema => a_object_schema,
                    a_object_name => a_object_name,
                    a_ddl_schema => l_ddl_schema )
            WHERE is_pk
                OR param_name IN ( 'a_err', 'a_act_user' )
            ORDER BY ordinal_position ) LOOP

        IF r.is_pk THEN
            l_pk_params := array_append ( l_pk_params, r.param_name ) ;
            l_where_cols := array_append ( l_where_cols, concat_ws (
                    ' ',
                    r.column_name,
                    '=',
                    r.param_name ) ) ;
        END IF ;

        l_calling_params := util_meta._append_parameter (
            a_parameters => l_calling_params,
            a_name => r.param_name,
            a_direction => r.param_direction,
            a_datatype => r.param_data_type,
            a_description => r.comments ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    IF array_length ( l_pk_params, 1 ) = 0 THEN
        RETURN 'ERROR: Table must have a primary key' ;
    END IF ;

    l_result := concat_ws (
        util_meta._new_line (),
        util_meta._snip_procedure_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_procedure_purpose => 'performs a delete on ' || a_object_name,
            a_language => 'plpgsql',
            a_assertions => l_assertions,
            a_calling_parameters => l_calling_params ),
        util_meta._snip_log_params ( a_parameters => l_calling_params ),
        '',
        util_meta._indent ( 1 ) || 'DELETE FROM ' || a_object_schema || '.' || a_object_name,
        util_meta._indent ( 2 )
            || 'WHERE '
            || array_to_string ( l_where_cols, util_meta._new_line () || util_meta._indent ( 3 ) || 'AND ' )
            || ' ;',
        util_meta._snip_procedure_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_comment => NULL::text,
            a_owner => a_owner,
            a_calling_parameters => l_calling_params ) ) ;

    RETURN util_meta._cleanup_whitespace ( l_result ) ;

END ;
$$ ;
