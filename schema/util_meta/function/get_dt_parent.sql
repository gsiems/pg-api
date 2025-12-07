CREATE OR REPLACE FUNCTION util_meta.get_dt_parent (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL )
RETURNS util_meta.ut_parent_table
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
DECLARE

    r record ;
    l_ret util_meta.ut_parent_table ;
    l_chk text ;
    l_chks text[] ;
    l_parent_noun text ;

BEGIN

    -- Determine if:
    --   1. there is a single FK relationship to a dt_ table and,
    --   2. the FK is a single column FK (implying the parent has a single column PK)
    -- If so then return the table info.
    -- If there are more than one dt_* parents... check again... this time
    -- checking if there is one that best matches the child table name.

    l_chks := array_append ( l_chks, '^dt_' ) ;
    l_chks := array_append ( l_chks, '^' || a_object_name || '_' ) ;
    FOREACH l_chk IN array l_chks LOOP

        FOR r IN (
            SELECT min ( column_names ) AS column_names,
                    min ( ref_schema_name ) AS ref_schema_name,
                    min ( ref_table_name ) AS ref_table_name,
                    min ( ref_full_table_name ) AS ref_full_table_name,
                    min ( ref_column_names ) AS ref_column_names,
                    count (*) AS kount
                FROM util_meta.foreign_keys
                WHERE schema_name = a_object_schema
                    AND table_name = a_object_name
                    AND ref_table_name ~ l_chk
                GROUP BY schema_name,
                    table_name ) LOOP

            IF r.kount = 0 THEN
                RETURN l_ret ;

            ELSIF r.kount = 1 THEN

                IF r.ref_column_names ~ ',' THEN
                    RETURN l_ret ;
                END IF ;

                l_parent_noun := util_meta.table_noun (
                    a_object_name => r.ref_table_name,
                    a_ddl_schema => a_ddl_schema ) ;

                l_ret.column_names := r.column_names ;
                l_ret.parent_schema := r.ref_schema_name ;
                l_ret.parent_name := r.ref_table_name ;
                l_ret.parent_full_name := r.ref_full_table_name ;
                l_ret.parent_noun := l_parent_noun ;
                l_ret.parent_column_names := r.ref_column_names ;

                RETURN l_ret ;

            END IF ;

        END LOOP ;
    END LOOP ;

    RETURN l_ret ;

END ;
$$ ;
