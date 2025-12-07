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
    l_full_object_name text ;
    --l_base_schema_name text ;

BEGIN

    l_full_object_name := a_proc_schema || '.' || a_proc_name ;
    --l_base_schema_name := util_meta.base_name ( a_proc_schema ) ;
    FOR r IN (
        WITH n AS (
            SELECT schema_name,
                    a_proc_name AS proc_name,
                    l_full_object_name AS full_proc_name,
                    util_meta.base_name ( schema_name ) AS base_schema_name,
                    util_meta.base_order ( schema_name, util_meta.base_name ( schema_name ) ) AS base_order
                FROM util_meta.schemas
        )
        SELECT schema_name,
                base_schema_name,
                base_order,
                proc_name,
                full_proc_name,
                CASE WHEN schema_name = base_schema_name THEN 1 ELSE base_order END AS schema_order
            FROM n
            ORDER BY 6,
                1 ) LOOP

        FOR r2 IN (
            SELECT obj.schema_name,
                    obj.object_name,
                    obj.full_object_name,
                    obj.base_object_type,
                    obj.object_type--,
                    --r.schema_name AS x,
                    --r.base_schema_name,
                    --r.proc_name,
                    --r.full_proc_name,
                    --r.schema_order,
                    --util_meta.base_order ( obj.object_name, r.proc_name ) AS base_object_order
                FROM util_meta.objects obj
                WHERE obj.schema_name ~ r.base_schema_name
                    AND obj.object_name ~ r.proc_name
                    AND obj.full_object_name IS DISTINCT FROM r.full_proc_name
                    AND obj.object_type IN ( 'function', 'procedure' )
                ORDER BY r.schema_order,
                    util_meta.base_order ( obj.object_name, r.proc_name ) ) LOOP

            l_ret.schema_name := r2.schema_name ;
            l_ret.object_name := r2.object_name ;
            l_ret.full_object_name := r2.full_object_name ;
            l_ret.base_object_type := r2.object_type ;
            l_ret.object_type := r2.object_type ;

            RETURN l_ret ;

        END LOOP ;
    END LOOP ;

    RETURN l_ret ;

END ;
$$ ;
