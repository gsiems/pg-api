CREATE OR REPLACE FUNCTION util_meta._find_func (
    a_calling_schema text DEFAULT NULL,
    a_calling_func text DEFAULT NULL,
    a_desired_func text DEFAULT NULL )
RETURNS util_meta.ut_object
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _find_func searches for an existing function/procedure where the schema isn't known.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_calling_schema               | in     | text       | The (name of the) schema that contains the function/procedure that wants to call the desired function |
| a_calling_func                 | in     | text       | The (name of the) the function/procedure that wants to call the desired function |
| a_desired_func                 | in     | text       | The (name of the) desired function to find         |

*/
DECLARE

    r record ;

    l_ret util_meta.ut_object ;
    l_full_calling_name text ;
    l_is_priv_schema boolean := false ;
    l_desired_is_priv boolean := false ;
    l_calling_base text ;

BEGIN

    l_full_calling_name := a_calling_schema || '.' || a_calling_func ;
    l_calling_base := util_meta._base_name ( a_calling_schema ) ;

    -- if the calling schema is obviously private then we don't want to be
    -- finding functions that aren't also in obviously private schemas
    IF a_calling_schema ~ '^priv_' OR a_calling_schema ~ '^_' OR a_calling_schema ~ '_priv$' THEN
        l_is_priv_schema := true ;
    END IF ;

    IF a_desired_func ~ '^priv_' OR a_desired_func ~ '^_' OR a_desired_func ~ '_priv$' THEN
        l_desired_is_priv := true ;
    END IF ;

    FOR r IN (
        WITH x AS (
            SELECT obj.schema_name,
                    obj.object_name,
                    obj.full_object_name,
                    obj.base_object_type,
                    obj.object_type,
                    CASE
                        WHEN obj.schema_name ~ '^priv_' OR obj.schema_name ~ '^_' OR obj.schema_name ~ '_priv$'
                            THEN true
                        ELSE false
                        END AS is_priv_schema,
                    CASE
                        WHEN obj.object_name ~ '^priv_' OR obj.object_name ~ '^_' OR obj.object_name ~ '_priv$'
                            THEN true
                        ELSE false
                        END AS is_priv_func,
                    util_meta._base_order ( obj.object_name, a_desired_func ) AS func_order,
                    CASE
                        WHEN a_calling_schema = obj.schema_name THEN 0
                        ELSE util_meta._base_order ( obj.schema_name, l_calling_base )
                        END AS schema_order
                FROM util_meta.objects obj
                WHERE obj.full_object_name != l_full_calling_name
                    AND obj.object_type IN ( 'function', 'procedure' )
                    AND ( obj.object_name = a_desired_func
                        OR ( NOT l_desired_is_priv
                            AND ( obj.object_name = 'priv_' || a_desired_func
                                OR obj.object_name = '_' || a_desired_func
                                OR obj.object_name = a_desired_func || '_priv' ) ) )
                    AND ( obj.schema_name = a_calling_schema
                        OR NOT l_is_priv_schema
                        OR ( obj.schema_name ~ '^priv_'
                            OR obj.schema_name ~ '^_'
                            OR obj.schema_name ~ '_priv$' ) )
        ),
        y AS (
            SELECT x.*,
                    row_number () OVER ( ORDER BY x.schema_order, x.func_order ) AS rn
                FROM x
        )
        SELECT *
            FROM y
            WHERE rn = 1 ) LOOP

        l_ret.schema_name := r.schema_name ;
        l_ret.object_name := r.object_name ;
        l_ret.full_object_name := r.full_object_name ;
        l_ret.base_object_type := r.object_type ;
        l_ret.object_type := r.object_type ;

        RETURN l_ret ;

    END LOOP ;

    RETURN l_ret ;

END ;
$$ ;
