CREATE OR REPLACE FUNCTION util_meta.find_view (
    a_proc_schema text DEFAULT NULL,
    a_table_schema text DEFAULT NULL,
    a_table_name text DEFAULT NULL )
RETURNS util_meta.ut_object
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function find_view searches for an existing view for a table.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_proc_schema                  | in     | text       | The (name of the) schema that contains the procedure that wants the view |
| a_table_schema                 | in     | text       | The (name of the) schema that contains the table for the view |
| a_table_name                   | in     | text       | The (name of the) table that the view is for       |

*/

DECLARE

    r record ;
    l_ret util_meta.ut_object ;
    l_view_name text ;

BEGIN

    l_view_name := util_meta.view_name ( a_table_name ) ;

    FOR r IN (
        WITH x AS (
            SELECT schema_name,
                    object_name,
                    full_object_name,
                    base_object_type,
                    object_type,
                    row_number () OVER (
                        ORDER BY CASE
                                WHEN schema_name IS NOT DISTINCT FROM a_proc_schema THEN 1
                                WHEN schema_name ~ '^priv_' THEN 2
                                WHEN schema_name ~ '^_' THEN 3
                                WHEN schema_name ~ '_priv$' THEN 4
                                WHEN schema_name IS NOT DISTINCT FROM a_table_schema THEN 5
                                ELSE 6
                                END
                            ) AS rn
                FROM util_meta.objects
                WHERE object_type IN ( 'view', 'materialized view' )
                    AND object_name = l_view_name
        )
        SELECT schema_name,
                object_name,
                full_object_name,
                base_object_type,
                object_type
            FROM x
            WHERE rn = 1 ) LOOP

        l_ret.schema_name := r.schema_name ;
        l_ret.object_name := r.object_name ;
        l_ret.full_object_name := r.full_object_name ;
        l_ret.base_object_type := r.base_object_type ;
        l_ret.object_type := r.object_type ;

        RETURN l_ret ;

    END LOOP ;

    RETURN l_ret ;

END ;
$$ ;
