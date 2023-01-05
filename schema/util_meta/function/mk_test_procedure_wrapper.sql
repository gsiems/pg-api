CREATE OR REPLACE FUNCTION util_meta.mk_test_procedure_wrapper (
    a_object_schema text default null,
    a_object_name text default null,
    a_test_schema text default null )
RETURNS text
LANGUAGE plpgsql stable
SECURITY DEFINER
AS $$
/**
Function mk_test_procedure_wrapper generates a testing function for wrapping a database procedure

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the procedure to wrap |
| a_object_name                  | in     | text       | The (name of the) procedure to wrap                |
| a_test_schema                  | in     | text       | The (name of the) schema to create the wrapper function in |

*/
DECLARE

    r record ;
    r2 record ;

    l_column_names text[] ;
    l_column_name text ;
    l_func_name text ;
    l_func_param_directions text[] ;
    l_func_param_names text[] ;
    l_func_param_types text[] ;
    l_local_var_names text[] ;
    l_local_var_types text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_proc_params text[] ;
    l_proc_type text ;
    l_result text ;
    l_table_name text ;
    l_table_schema text ;
    l_test text ;
    l_view_name text ;
    l_where_cols text[] ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified procedure exists
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'procedure' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_proc_type := split_part ( a_object_name, '_', 1 ) ; -- insert, update, delete, upsert
    l_func_name := concat_ws ( '__', a_object_schema, a_object_name ) ;

    ----------------------------------------------------------------------------
    FOR r IN (
        SELECT schema_name,
                object_name,
                object_type,
                param_name,
                data_type,
                param_default,
                param_direction,
                arg_position,
                local_var_name,
                column_name,
                comments
            FROM util_meta.calling_parameters (
                a_object_schema => a_object_schema,
                a_object_name => a_object_name,
                a_object_type => 'procedure' ) ) LOOP

        l_param_names := array_append ( l_param_names, r.param_name ) ;
        l_param_directions := array_append ( l_param_directions, r.param_direction ) ;

        IF r.param_direction = 'inout' THEN

            l_local_var_names := array_append ( l_local_var_names, r.local_var_name ) ;
            l_local_var_types := array_append ( l_local_var_types, r.data_type ) ;
            l_proc_params := array_append ( l_proc_params, util_meta.indent (2) || concat_ws ( ' ', r.param_name, '=>', r.local_var_name ) ) ;

            IF r.param_name = 'a_err' THEN
                l_func_param_names := array_append ( l_func_param_names, null::text ) ;
                l_func_param_directions := array_append ( l_func_param_directions, null::text ) ;
                l_func_param_types := array_append ( l_func_param_types, null::text ) ;
            ELSE
                l_func_param_names := array_append ( l_func_param_names, r.param_name ) ;
                l_func_param_directions := array_append ( l_func_param_directions, 'in' ) ;
                l_func_param_types := array_append ( l_func_param_types, r.data_type ) ;
            END IF ;

        ELSIF r.param_direction = 'out' THEN

            l_local_var_names := array_append ( l_local_var_names, r.local_var_name ) ;
            l_local_var_types := array_append ( l_local_var_types, r.data_type  ) ;

            l_proc_params := array_append ( l_proc_params, util_meta.indent (2) || concat_ws ( ' ', r.param_name, '=>', r.local_var_name ) ) ;
            l_func_param_names := array_append ( l_func_param_names, null::text ) ;
            l_func_param_directions := array_append ( l_func_param_directions, null::text ) ;
            l_func_param_types := array_append ( l_func_param_types, null::text ) ;

        ELSE

            l_local_var_names := array_append ( l_local_var_names, null::text ) ;
            l_local_var_types := array_append ( l_local_var_types, null::text ) ;

            l_proc_params := array_append ( l_proc_params, util_meta.indent (2) || concat_ws ( ' ', r.param_name, '=>', r.param_name ) ) ;
            l_func_param_names := array_append ( l_func_param_names, r.param_name ) ;
            l_func_param_directions := array_append ( l_func_param_directions, 'in' ) ;
            l_func_param_types := array_append ( l_func_param_types, r.data_type ) ;

        END IF ;

    END LOOP ;

    IF l_proc_type IN ( 'update', 'upsert' ) THEN
        l_local_var_names := array_append ( l_local_var_names, 'r' ) ;
        l_local_var_types := array_append ( l_local_var_types, 'record' ) ;
    END IF ;

    ----------------------------------------------------------------------------
    l_result := concat_ws ( util_meta.new_line (),
        l_result,
        util_meta.snippet_function_frontmatter (
            a_ddl_schema => a_test_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_return_type => 'boolean',
            a_returns_set => false,
            a_param_names => l_func_param_names,
            a_directions => l_func_param_directions,
            a_datatypes => l_func_param_types ),
        util_meta.snippet_declare_variables (
            a_var_names => l_local_var_names,
            a_var_datatypes => l_local_var_types ),
        '',
        'BEGIN',
        '' ) ;

    ----------------------------------------------------------------------------
    -- Preset any local variables.
    FOR idx IN 1..array_length ( l_local_var_names, 1 ) LOOP

        IF l_local_var_names[idx] IS NOT NULL THEN

            IF l_param_directions[idx] = 'inout' AND l_local_var_names[idx] <> 'l_err' THEN

                l_result := concat_ws ( util_meta.new_line (),
                    l_result,
                    '',
                    util_meta.indent (1) || concat_ws ( ' ', l_local_var_names[idx], ':=', l_param_names[idx], ';' ) ) ;

            END IF ;

        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Add the procedure call
    IF l_proc_type IN ( 'insert', 'update', 'upsert', 'delete' ) THEN

        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            '',
            util_meta.indent (1) || concat_ws ( ' ', 'call', a_object_schema || '.' || a_object_name, '(' ),
            array_to_string ( l_proc_params, ',' || util_meta.new_line () ) || ' ) ;' ) ;

    END IF ;

    ----------------------------------------------------------------------------
    -- Add the local parameter checks
    -- check l_err first
    FOR idx IN 1..array_length ( l_local_var_names, 1 ) LOOP

        IF l_local_var_names[idx] IS NOT NULL THEN

            IF l_local_var_names[idx] = 'l_err' THEN

                l_result := concat_ws ( util_meta.new_line (),
                    l_result,
                    '',
                    util_meta.indent (1) || 'IF ' || l_local_var_names[idx] || ' IS NOT NULL THEN',
                    util_meta.indent (2) || '--RAISE NOTICE E''%'', ' || l_local_var_names[idx] || ' ;',
                    util_meta.indent (2) || 'RETURN false ;',
                    util_meta.indent (1) || 'END IF ;' ) ;

            END IF ;

        END IF ;

    END LOOP ;

    -- check the rest
    FOR idx IN 1..array_length ( l_local_var_names, 1 ) LOOP

        IF l_local_var_names[idx] IS NOT NULL THEN

            IF l_local_var_names[idx] NOT IN ( 'r', 'l_err' ) THEN

                l_result := concat_ws ( util_meta.new_line (),
                    l_result,
                    '',
                    util_meta.indent (1) || 'IF ' || l_local_var_names[idx] || ' IS NULL THEN',
                    util_meta.indent (2) || '--RAISE NOTICE ''' || l_local_var_names[idx] || ' is null'' ;',
                    util_meta.indent (2) || 'RETURN false ;',
                    util_meta.indent (1) || 'END IF ;' ) ;

            END IF ;

        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Add the checks for new values
    IF l_proc_type IN ( 'insert', 'update', 'upsert' ) THEN

        ------------------------------------------------------------------------
        -- For insert, update, and upsert we want to add checks to ensure that the
        -- new table data matches the submitted data.
        -- ASSERTION: the view exists in the same schema as the procedure being wrapped
        FOR r IN (
            SELECT prefix
                FROM (
                    VALUES
                        ( 'dv_' ),
                        ( 'rv_' )
                    ) AS dat ( prefix ) ) LOOP

            l_test := regexp_replace ( a_object_name, '^' || l_proc_type || '_', '' ) ;
            l_test := r.prefix || regexp_replace ( l_test, '^rt_', '' ) ;

            IF util_meta.is_valid_object ( a_object_schema, l_test, 'view' ) THEN
                l_view_name := l_test ;
                EXIT ;
            END IF ;

        END LOOP ;

        IF l_view_name IS NOT NULL THEN

            -- Having found the view, search for the table
            FOR r IN (
                SELECT max ( schema_name ) AS table_schema,
                        object_name AS table_name,
                        count (*) AS kount
                    FROM util_meta.objects
                    WHERE object_name = regexp_replace ( l_view_name, '^([dr])v', '\1t' )
                        AND object_type = 'table'
                    GROUP BY object_name ) LOOP

                -- ASSERTION: If there is only one matching table then it is the one we want
                -- The table is used for determining the primary key columns to select against
                IF r.kount = 1 THEN

                    FOR r2 IN (
                        WITH v_col AS (
                            SELECT column_name,
                                    'a_' || column_name AS param_name,
                                    'l_' || column_name AS local_var_name,
                                    ordinal_position,
                                    is_pk
                                FROM util_meta.columns
                                WHERE schema_name = a_object_schema
                                    AND object_name = l_view_name
                                    AND 'a_' || column_name = ANY ( l_param_names )
                        ),
                        t_col AS (
                            SELECT column_name,
                                    is_pk
                                FROM util_meta.columns
                                WHERE schema_name = r.table_schema
                                    AND object_name = r.table_name
                                    --AND object_type = 'table'
                                    AND 'a_' || column_name = ANY ( l_param_names )
                        )
                        SELECT v_col.column_name,
                                v_col.param_name,
                                v_col.local_var_name,
                                coalesce ( t_col.is_pk, false ) AS is_pk
                            FROM v_col
                            FULL JOIN t_col
                                ON ( t_col.column_name = v_col.column_name )
                            ORDER BY v_col.ordinal_position ) LOOP

                        IF r2.is_pk THEN

                            IF r2.local_var_name = ANY ( l_local_var_names ) THEN
                                l_where_cols := array_append ( l_where_cols, concat_ws ( ' ', r2.column_name, '=', r2.local_var_name ) ) ;
                            ELSE
                                l_where_cols := array_append ( l_where_cols, concat_ws ( ' ', r2.column_name, '=', r2.param_name ) ) ;
                            END IF ;

                        ELSE

                            l_column_names := array_append ( l_column_names, r2.column_name ) ;

                        END IF ;

                    END LOOP ;

                END IF ;

            END LOOP ;

        END IF ;

        IF array_length ( l_where_cols, 1 ) > 0 AND array_length ( l_column_names, 1 ) > 0 THEN

            -- NB: We select against the view based on the assertion that, if there are any transformations to the data,
            -- the view data/datatypes will better match the calling parameters data/datatypes
            l_result := concat_ws ( util_meta.new_line (),
                l_result,
                '',
                util_meta.indent (1) || 'FOR r IN (',
                util_meta.indent (2) || 'SELECT ' || array_to_string ( l_column_names, ',' || util_meta.new_line () || util_meta.indent (4) ),
                util_meta.indent (3) || 'FROM ' || a_object_schema || '.' || l_view_name,
                util_meta.indent (3) || 'WHERE ' || array_to_string ( l_where_cols, ',' || util_meta.new_line () || util_meta.indent (5) || 'AND ' ) || ' ) LOOP' ) ;

            FOREACH l_column_name IN ARRAY l_column_names LOOP

                l_result := concat_ws ( util_meta.new_line (),
                    l_result,
                    '',
                    util_meta.indent (2) || 'IF a_' || l_column_name || ' IS NOT NULL AND a_' || l_column_name || ' IS DISTINCT FROM r.' || l_column_name || ' THEN',
                    util_meta.indent (3) || 'RAISE NOTICE E''' || l_column_name || ' did not update. expected %, got %'', a_' || l_column_name  || ', r.' || l_column_name || ' ;',
                    util_meta.indent (3) || 'RETURN false ;',
                    util_meta.indent (2) || 'END IF ;' ) ;

            END LOOP;

            l_result := concat_ws ( util_meta.new_line (),
                l_result,
                '',
                util_meta.indent (1) || 'END LOOP ;' ) ;

        ELSE

            l_result := concat_ws ( util_meta.new_line (),
                l_result,
                '',
                '-- TODO: could not resolve the table/view meta-data for reviewing data changes',
                '' ) ;

        END IF ;

    END IF ;

    -- TODO: for delete procedures ensure that the delete succeeded

    --------------------------------------------------------------------
    -- end-matter
    l_result := concat_ws ( util_meta.new_line (),
        l_result,
        '',
        util_meta.indent (1) || 'RETURN true ;',
        '',
        'END ;',
        '$' || '$ ;' ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
