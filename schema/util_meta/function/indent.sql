CREATE OR REPLACE FUNCTION util_meta.indent (
    a_count integer default null )
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
/**
Function indent returns the specified amount of indentation for start of a line

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_count                        | in     | integer    | The number of indents                              |

*/

    WITH x AS (
        SELECT coalesce ( util_meta.resolve_parameter (
                    a_name => 'indent_char' ), '    ' ) AS chars
    )
    SELECT CASE
                WHEN a_count IS NULL THEN chars
                WHEN a_count BETWEEN 1 AND 10 THEN repeat ( chars, a_count )
                ELSE chars
                END AS indent
        FROM x ;

$$ ;
