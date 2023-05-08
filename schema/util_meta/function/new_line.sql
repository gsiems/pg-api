CREATE OR REPLACE FUNCTION util_meta.new_line (
    a_count integer default null )
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$

    WITH x AS (
        SELECT E'\n' AS new_line
    )
    SELECT CASE
                WHEN a_count IS NULL THEN new_line
                WHEN a_count BETWEEN 1 AND 10 THEN repeat ( new_line, a_count )
                ELSE new_line
                END AS new_lines
        FROM x ;

$$ ;
