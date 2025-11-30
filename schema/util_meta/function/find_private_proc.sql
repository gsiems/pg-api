CREATE OR REPLACE FUNCTION util_meta.find_private_proc (
    a_proc_schema text DEFAULT NULL,
    a_proc_name text DEFAULT NULL )
RETURNS util_meta.ut_object
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function find_private_proc searches for an existing "private" procedure for an API procedure.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_proc_schema                  | in     | text       | The (name of the) schema that contains the public procedure |
| a_proc_name                    | in     | text       | The (name of the) public procedure                 |

*/
DECLARE

    r record ;
    r2 record ;
    l_ret util_meta.ut_object ;

BEGIN

    FOR r IN (
        SELECT schema_name
            FROM util_meta.schemas
            ORDER BY CASE
                    WHEN schema_name IS NOT DISTINCT FROM a_proc_schema THEN 1
                    WHEN schema_name ~ '^priv_' THEN 2
                    WHEN schema_name ~ '^_' THEN 3
                    WHEN schema_name ~ '_priv$' THEN 4
                    --WHEN schema_name IS NOT DISTINCT FROM a_table_schema THEN 5
                    ELSE 6
                    END ) LOOP

        FOR r2 IN (
            SELECT schema_name,
                    object_name,
                    full_object_name,
                    base_object_type,
                    object_type
                FROM util_meta.objects
                WHERE schema_name = r.schema_name
                    AND r.schema_name || '.' || a_proc_name IS NOT DISTINCT FROM full_object_name
                ORDER BY CASE
                        WHEN object_name IS NOT DISTINCT FROM a_proc_name THEN 1
                        WHEN object_name = 'priv_' || a_proc_name THEN 2
                        WHEN object_name = '_' || a_proc_name THEN 3
                        WHEN object_name = a_proc_name || '_priv$' THEN 4
                        ELSE 6
                        END ) LOOP

            l_ret.schema := r2.schema_name ;
            l_ret.name := r2.object_name ;
            l_ret.full_name := r2.full_object_name ;
            l_ret.base_object_type := r2.object_type ;
            l_ret.object_type := r2.object_type ;

            RETURN l_ret ;

        END LOOP ;
    END LOOP ;

    RETURN l_ret ;

END ;
$$ ;
