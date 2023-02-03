CREATE OR REPLACE FUNCTION util_meta.boolean_casting (
    a_cast_booleans_as text default null )
RETURNS TABLE (
    boolean_type text,
    true_val text,
    false_val text )
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
/**
Function boolean_casting

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_cast_booleans_as             | in     | text       | The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values) |

*/

    WITH base AS (
        SELECT a_cast_booleans_as AS cast_booleans_as,
                CASE
                    WHEN a_cast_booleans_as IS NULL THEN 'boolean'
                    WHEN a_cast_booleans_as = '1,0' THEN 'integer'
                    ELSE 'text'
                    END AS boolean_type,
                CASE
                    WHEN a_cast_booleans_as IS NULL THEN 'true'::text
                    ELSE trim ( split_part ( a_cast_booleans_as, ',', 1 ) )
                    END AS true_val,
                CASE
                    WHEN a_cast_booleans_as IS NULL THEN 'false'::text
                    ELSE trim ( split_part ( a_cast_booleans_as, ',', 2 ) )
                    END AS false_val
    )
    SELECT boolean_type,
            CASE
                WHEN boolean_type = 'text' THEN ( quote_literal ( true_val ) )::text || '::text'
                ELSE true_val
                END AS true_val,
            CASE
                WHEN boolean_type = 'text' THEN ( quote_literal ( false_val ) )::text || '::text'
                ELSE false_val
                END AS false_val
        FROM base ;

$$ ;
