CREATE OR REPLACE FUNCTION util_meta.mk_priv_dml_procedure (
    a_object_schema text default null,
    a_object_name text default null,
    a_ddl_schema text default null,
    a_cast_booleans_as text default null,
    a_insert_audit_columns text default null,
    a_update_audit_columns text default null,
    a_owner text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function mk_priv_delete_procedure generates a draft "private" delete procedure for a table

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as  (if booleans are going to be cast to non-boolean values) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the procedure |

Note that this should work for dt and rt table types

Note that the generated procedure has no permissions check and is not intended
to be called from outside the database

*/
DECLARE

    r record ;

    l_ddl_schema text ;
    l_log_err_line text ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;
    l_pk_params text[] ;
    l_proc_name text ;
    l_result text ;
    l_table_noun text ;
    l_where_cols text[] ;

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
    l_proc_name := 'priv_delete_' || l_table_noun ;

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
            l_pk_params := array_append ( l_pk_params, r.param_name ) ;
            l_where_cols := array_append ( l_where_cols, concat_ws ( ' ', r.column_name, '=', r.param_name ) ) ;
        END IF ;

        l_param_names := array_append ( l_param_names, r.param_name ) ;
        l_param_directions := array_append ( l_param_directions, r.param_direction ) ;
        l_param_types := array_append ( l_param_types, r.param_data_type ) ;
        l_param_comments := array_append ( l_param_comments, r.comments ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    IF array_length ( l_pk_params, 1 ) = 0 THEN
        RETURN 'ERROR: Table must have a primary key' ;
    END IF ;

    l_result := concat_ws ( util_meta.new_line (),
        util_meta.snippet_procedure_frontmatter (
            a_object_name => a_object_name,
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_procedure_purpose => 'performs a delete on ' || a_object_name,
            a_language => 'plpgsql',
            a_param_names => l_param_names,
            a_param_directions => l_param_directions,
            a_param_datatypes => l_param_types,
            a_param_comments => l_param_comments,
            a_local_var_names => l_local_params,
            a_local_var_datatypes => l_local_types ),
        util_meta.snippet_log_params (
            a_param_names => l_param_names,
            a_datatypes => l_param_types ),
        '',
        util_meta.indent (1) || 'DELETE FROM ' || a_object_schema || '.' || a_object_name,
        util_meta.indent (2) || 'WHERE ' || array_to_string ( l_where_cols, util_meta.new_line () || util_meta.indent (3) || 'AND ' ) || ' ;',
        util_meta.snippet_procedure_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_procedure_name => l_proc_name,
            a_comment => null::text,
            a_owner => a_owner,
            a_datatypes => l_param_types ) ) ;

    RETURN l_result ;

END ;
$$ ;
