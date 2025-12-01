CREATE OR REPLACE FUNCTION util_meta.mk_view (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_cast_booleans_as text DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_view generates a draft view of a table

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the view for     |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the view in (if different from the table schema) |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the view  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted select on the view |

The goal is to combine the table columns of the specified table with the
natural key columns of any referenced tables to create a draft view.

This does not (currently) attempt to recurse beyond the parent tables for the
specified table (parents of parents).

Aspirational goal: to recurse parent reference tables.

Aspirational goal: to recognize self-referential tables and add the recursive
CTE for all parent records.

Note that this should work for all table types (dt, rt, st)

*/

DECLARE

    r record ;
    col record ;
    fk record ;
    fk_col record ;

    l_result text ;

    has_join boolean ;
    l_column_alias text ;
    l_column_comment text ;
    l_columns text[] ;
    l_comments text[] ;
    l_ddl_schema text ;
    l_full_view_name text ;
    l_full_table_name text ;
    l_joins text[] ;
    l_table_alias text := 'base' ;
    l_view_name text ;

    l_boolean_type text ;
    l_true_val text ;
    l_false_val text ;
    l_boolean_transform text ;

    l_fnk_count bigint ;
    l_fk_tab text ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified table exists
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;
    l_view_name := util_meta.view_name ( a_object_name ) ;
    l_full_view_name := concat_ws ( '.', l_ddl_schema, l_view_name ) ;
    l_full_table_name := concat_ws ( '.', a_object_schema, a_object_name ) ;

    ----------------------------------------------------------------------------
    -- Determine the comment for the view
    FOR r IN (
        SELECT schema_name,
                object_name,
                comments
            FROM util_meta.objects
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
                AND object_type = 'table' ) LOOP

        l_comments := array_append (
            l_comments,
            util_meta.snippet_object_comment (
                a_ddl_schema => l_ddl_schema,
                a_object_name => l_view_name,
                a_object_type => 'view',
                a_comment => 'View of: ' || coalesce ( r.comments, 'TBD' ) ) ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    FOR r IN (
        SELECT boolean_type,
                true_val,
                false_val
            FROM util_meta.boolean_casting ( a_cast_booleans_as ) ) LOOP

        l_boolean_type := r.boolean_type ;
        l_true_val := r.true_val ;
        l_false_val := r.false_val ;

        IF coalesce ( l_true_val, '' ) = '' OR coalesce ( l_false_val, '' ) = '' THEN

            RETURN 'ERROR: Could not resolve true/false values' ;

        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    FOR col IN (
        SELECT column_name,
                concat_ws ( '.', l_table_alias, column_name ) AS table_column,
                concat_ws ( '.', l_full_view_name, column_name ) AS full_column_name,
                data_type,
                ordinal_position,
                CASE WHEN is_nullable THEN 'LEFT JOIN' ELSE 'JOIN' END AS join_type,
                't' || lpad ( ordinal_position::text, 3, '0' ) AS join_alias,
                comments
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
            ORDER BY ordinal_position ) LOOP

        IF col.data_type = 'boolean' AND l_boolean_type <> 'boolean' THEN

            l_boolean_transform := concat_ws (
                util_meta.new_line () || util_meta.indent ( 3 ),
                'CASE',
                concat_ws (
                    ' ',
                    'WHEN',
                    col.table_column,
                    'THEN',
                    l_true_val ),
                concat_ws ( ' ', 'ELSE', l_false_val ),
                concat_ws ( ' ', 'END AS', col.column_name ) ) ;

            l_columns := array_append ( l_columns, l_boolean_transform ) ;

        ELSE

            l_columns := array_append ( l_columns, col.table_column ) ;

        END IF ;

        l_comments := array_append (
            l_comments,
            util_meta.snippet_object_comment (
                a_ddl_schema => l_ddl_schema,
                a_object_name => l_view_name || '.' || col.column_name,
                a_object_type => 'column',
                a_comment => col.comments ) ) ;

        FOR fk IN (
            SELECT fks.ref_schema_name,
                    fks.ref_table_name,
                    fks.ref_full_table_name,
                    col.join_alias || '.' || fks.ref_column_names AS join_column_name
                FROM util_meta.foreign_keys fks
                WHERE fks.schema_name = a_object_schema
                    AND fks.table_name = a_object_name
                    AND fks.column_names = col.column_name
                    AND fks.ref_column_names !~ ',' ) LOOP

            has_join := false ;

            l_fk_tab := util_meta.table_noun (
                a_object_name => fk.ref_table_name,
                a_ddl_schema => fk.ref_schema_name ) ;

            -- Determine if the parent table has a multi-column natural key or not
            SELECT count (*)
                INTO l_fnk_count
                FROM util_meta.columns
                WHERE schema_name = fk.ref_schema_name
                    AND object_name = fk.ref_table_name
                    AND is_nk ;

            FOR fk_col IN (
                SELECT column_name,
                        col.join_alias || '.' || column_name AS full_column_name,
                        comments
                    FROM util_meta.columns
                    WHERE schema_name = fk.ref_schema_name
                        AND object_name = fk.ref_table_name
                        AND is_nk
                    ORDER BY ordinal_position ) LOOP

                has_join := true ;

                IF l_fnk_count > 1 THEN

                    IF fk_col.column_name = 'name' THEN

                        IF col.column_name ~ '_id$' THEN
                            l_column_alias := regexp_replace ( col.column_name, '_id$', '_' || l_fk_tab ) ;
                        ELSIF col.column_name ~ '_id_' THEN
                            l_column_alias := regexp_replace ( col.column_name, '_id_', '_' || l_fk_tab || '_' ) ;
                        ELSE
                            l_column_alias := col.column_name || '_' || l_fk_tab ;
                        END IF ;
                    ELSE

                        IF col.column_name ~ '_id$' THEN
                            l_column_alias := regexp_replace ( col.column_name, '_id$', '_' )
                                || '_'
                                || fk_col.column_name ;
                        ELSIF col.column_name ~ '_id_' THEN
                            l_column_alias := regexp_replace (
                                col.column_name || '_' || fk_col.column_name,
                                '_id_',
                                '_' ) ;
                            --                        l_column_alias := regexp_replace ( col.column_name, '_id_', '_' || l_fk_tab || '_' ) ;
                        ELSE
                            l_column_alias := col.column_name || '_' || l_fk_tab ;
                        END IF ;

                    END IF ;

                ELSE

                    IF col.column_name ~ '_id$' THEN
                        l_column_alias := regexp_replace ( col.column_name, '_id$', '' ) ;
                    ELSIF col.column_name ~ '_id_' THEN
                        l_column_alias := regexp_replace ( col.column_name, '_id_', '_' ) ;
                        --                    ELSIF fk_col.column_name = 'name' THEN
                        --                        l_column_alias := col.column_name || '_' || l_fk_tab ;
                    ELSE
                        l_column_alias := col.column_name || '_' || l_fk_tab ;
                    END IF ;

                END IF ;

                l_columns := array_append (
                    l_columns,
                    concat_ws (
                        ' ',
                        fk_col.full_column_name,
                        'AS',
                        l_column_alias ) ) ;

                l_column_comment := concat_ws (
                    ' ',
                    'The',
                    replace ( fk_col.column_name, '_', ' ' ),
                    'for the',
                    replace ( l_column_alias, '_', ' ' ) ) ;

                l_comments := array_append (
                    l_comments,
                    util_meta.snippet_object_comment (
                        a_ddl_schema => l_ddl_schema,
                        a_object_name => l_view_name || '.' || l_column_alias,
                        a_object_type => 'column',
                        a_comment => l_column_comment ) ) ;

            END LOOP ;

            IF has_join THEN
                l_joins := array_append (
                    l_joins,
                    util_meta.indent ( 1 )
                        || concat_ws (
                            ' ',
                            col.join_type,
                            fk.ref_full_table_name,
                            col.join_alias ) ) ;

                l_joins := array_append (
                    l_joins,
                    util_meta.indent ( 2 )
                        || concat_ws (
                            ' ',
                            'ON',
                            '(',
                            fk.join_column_name,
                            '=',
                            col.table_column,
                            ')' ) ) ;
            END IF ;

        END LOOP ;

    END LOOP ;

    l_result := concat_ws (
        util_meta.new_line (),
        l_result,
        'CREATE OR REPLACE VIEW ' || l_full_view_name,
        'AS',
        concat_ws (
            ' ',
            'SELECT',
            array_to_string ( l_columns, ',' || util_meta.new_line () || util_meta.indent ( 2 ) ) ),
        util_meta.indent ( 1 ) || concat_ws (
            ' ',
            'FROM',
            l_full_table_name,
            l_table_alias ) ) ;

    IF array_length ( l_joins, 1 ) > 0 THEN

        l_result := concat_ws ( util_meta.new_line (), l_result, array_to_string ( l_joins, util_meta.new_line () ) ) ;

    END IF ;

    l_result := concat_ws (
        util_meta.new_line (),
        l_result || ' ;',
        '',
        util_meta.snippet_owners_and_grants (
            a_ddl_schema => a_ddl_schema,
            a_object_name => l_view_name,
            a_object_type => 'view',
            a_owner => a_owner,
            a_grantees => a_grantees ),
        '',
        array_to_string ( l_comments, util_meta.new_line () ),
        '' ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
