CREATE OR REPLACE FUNCTION util_meta.mk_table_migration (
    a_object_schema text default null,
    a_object_name text default null )
RETURNS text
LANGUAGE plpgsql stable
SECURITY DEFINER
AS $$
/**
Function mk_table_migration generates a script for migrating the structure of a table

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table to migrate |
| a_object_name                  | in     | text       | The (name of the) table to create a migration script for |

*/
DECLARE

    r record ;

    l_columns text[] ;
    l_full_table_name text ;
    l_grants text[] ;
    l_new_line text ;
    l_pk_cols text[] ;
    l_result text ;
    l_seq_name text ;
    l_seq_stmt text ;
    l_set_sequences text[] ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified object is valid
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    -- Ensure that a backup table does not exist
    IF util_meta.is_valid_object ( 'bak_' || a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: a backup table already exists' ;
    END IF ;

    l_full_table_name := a_object_schema || '.' || a_object_name ;
    l_new_line := util_meta.new_line () ;

    ----------------------------------------------------------------------------
    -- Drop any foreign key relationships against the specified table
    FOR r IN (
        SELECT DISTINCT 'ALTER TABLE ' || full_table_name || ' DROP CONSTRAINT ' || constraint_name || ' ;' AS cmd
            FROM util_meta.foreign_keys
            WHERE ref_schema_name = a_object_schema
                AND ref_table_name = a_object_name ) LOOP

            l_result := concat_ws ( l_new_line,
                l_result,
                r.cmd ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Ensure that there is a backup schema to move the existing table to
    l_result := concat_ws ( l_new_line,
        l_result,
        '',
        'CREATE SCHEMA IF NOT EXISTS bak_' || a_object_schema || ' ;' ) ;

    ----------------------------------------------------------------------------
    -- Move the existing table
    l_result := concat_ws ( l_new_line,
        l_result,
        '',
        'ALTER TABLE ' || l_full_table_name || ' SET SCHEMA bak_' || a_object_schema || ' ;' ) ;

    ----------------------------------------------------------------------------
    -- Execute the table creation DDL file
    FOR r IN (
        SELECT '\i ' || concat_ws ( '/', directory_name, file_name ) AS cmd
            FROM util_meta.objects
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name ) LOOP

            l_result := concat_ws ( l_new_line,
                l_result,
                '',
                r.cmd ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Copy the data from the backup to the new table
    FOR r IN (
        SELECT column_name,
                is_pk,
                column_default
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
            ORDER BY ordinal_position ) LOOP

        l_columns := array_append ( l_columns, r.column_name ) ;

        IF r.column_default ~ '^nextval' THEN

            l_seq_name := split_part ( r.column_default, '''', 2 ) ;

            l_seq_stmt := concat_ws ( l_new_line,
                'WITH cv AS (',
                util_meta.indent (1) || 'SELECT 1 AS rn,',
                util_meta.indent (3) || 'last_value',
                util_meta.indent (2) || 'FROM ' || l_seq_name,
                '),',
                'mv AS (',
                util_meta.indent (1) || 'SELECT 1 AS rn,',
                util_meta.indent (3) || 'max ( ' || r.column_name || ' ) AS max_value',
                util_meta.indent (2) || 'FROM ' || l_full_table_name,
                ')',
                'SELECT pg_catalog.setval ( ' || quote_literal ( l_seq_name ) || ', mv.max_value, false )',
                util_meta.indent (1) || 'FROM mv',
                util_meta.indent (1) || 'JOIN cv',
                util_meta.indent (2) || 'ON ( cv.rn = mv.rn )',
                util_meta.indent (1) || 'WHERE mv.max_value > cv.last_value ;' ) ;

            l_set_sequences := array_append ( l_set_sequences, l_seq_stmt ) ;

        END IF ;

        IF r.is_pk THEN
            l_pk_cols := array_append ( l_pk_cols, r.column_name ) ;
        END IF ;

    END LOOP ;

    l_result := concat_ws ( l_new_line,
        l_result,
        '',
        'INSERT INTO ' || l_full_table_name || ' (',
        util_meta.indent (3) || array_to_string ( l_columns, ',' || l_new_line || util_meta.indent (3) ) || ' )',
        util_meta.indent (1) || 'SELECT ' || array_to_string ( l_columns, ',' || l_new_line || util_meta.indent (3) ),
        util_meta.indent (2) || 'FROM bak_' || a_object_schema || '.' || a_object_name,
        util_meta.indent (2) || 'ORDER BY ' || array_to_string ( l_pk_cols, ',' || l_new_line || util_meta.indent (3) ) || ' ;' ) ;

    ----------------------------------------------------------------------------
    -- VACUUM ANALYZE
    l_result := concat_ws ( l_new_line,
        l_result,
        '',
        'VACUUM ANALYZE ' || l_full_table_name || ' ;' ) ;

    ----------------------------------------------------------------------------
    -- Reset sequences
    IF array_length ( l_set_sequences, 1 ) > 0 THEN
        l_result := concat_ws ( l_new_line,
            l_result,
            '',
            array_to_string ( l_set_sequences,  l_new_line ) ) ;
    END IF ;

    ----------------------------------------------------------------------------
    -- Re-create the foreign keys against the re-built table
    FOR r IN (
        SELECT DISTINCT 'ALTER TABLE ' || full_table_name
                    || ' ADD CONSTRAINT ' || constraint_name || ' FOREIGN KEY ( '
                    || column_names || ' ) REFERENCES ' || ref_full_table_name || ' ( '
                    || ref_column_names || ' )'
                    || CASE
                        WHEN update_rule <> 'NO ACTION' THEN ' ON UPDATE ' || update_rule
                        ELSE ''
                        END
                    || CASE
                        WHEN delete_rule <> 'NO ACTION' THEN ' ON DELETE ' || delete_rule
                        ELSE ''
                        END || ' ;' AS cmd
            FROM util_meta.foreign_keys
            WHERE ref_schema_name = a_object_schema
                AND ref_table_name = a_object_name ) LOOP

        l_result := concat_ws ( l_new_line,
            l_result,
            '',
            r.cmd ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Restore any grants
    FOR r IN (
        WITH base AS (
            SELECT CASE
                        WHEN object_type IN ( 'schema', 'database' ) THEN object_name
                        ELSE object_schema || '.' || object_name
                        END AS obj_name,
                    CASE
                        WHEN object_type NOT IN ( 'table', 'view', 'materialized_view' ) THEN 'ON ' || object_type
                        END AS obj_type,
                    privilege_type,
                    grantee,
                    CASE WHEN is_grantable THEN 'WITH GRANT OPTION'
                        END AS with_grant
                FROM util_meta.object_grants
                WHERE object_schema = a_object_schema
                    AND object_name = a_object_name
                ORDER BY privilege_type,
                    grantee
        )
        SELECT concat_ws ( ' ', 'GRANT', privilege_type, 'ON', obj_name, 'TO', grantee, with_grant, ';' ) AS cmd
            FROM base ) LOOP


        l_grants := array_append ( l_grants, r.cmd ) ;

    END LOOP ;

    IF array_length ( l_grants, 1 ) > 0 THEN
        l_result := concat_ws ( l_new_line,
            l_result,
            '',
            array_to_string ( l_grants,  l_new_line ) ) ;

    END IF ;

    ----------------------------------------------------------------------------
    -- Set a reminder
    l_result := concat_ws ( l_new_line,
        l_result,
        '',
        '-- Remember to "DROP TABLE bak_' || l_full_table_name || ' ;" once the migration is verified' ) ;

    RETURN l_result ;

END ;
$$ ;
