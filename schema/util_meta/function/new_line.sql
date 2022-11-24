CREATE OR REPLACE FUNCTION util_meta.new_line (
    a_count integer default null )
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$

/*
    WITH x AS (
        SELECT chr ( 10 ) AS nl
    )
    SELECT CASE
                WHEN a_count BETWEEN 1 AND 10 THEN repeat ( nl, a_count )
                ELSE nl
                END AS new_line
        FROM x ;
*/

SELECT CASE
            WHEN a_count BETWEEN 1 AND 10 THEN repeat ( E'\n', a_count )
            ELSE E'\n'
            END ;

$$ ;
