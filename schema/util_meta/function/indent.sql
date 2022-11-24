CREATE OR REPLACE FUNCTION util_meta.indent (
    a_count integer default null )
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$

    WITH x AS (
        SELECT '    ' AS spaces
    )
    SELECT CASE
                WHEN a_count BETWEEN 1 AND 10 THEN repeat ( spaces, a_count )
                ELSE spaces
                END AS indent
        FROM x ;

$$ ;
