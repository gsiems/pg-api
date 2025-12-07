CREATE OR REPLACE FUNCTION util_meta.view_name (
    a_table_name text DEFAULT NULL,
    a_notation text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function view_name converts a table name to a view name

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_table_name                   | in     | text       | The (name of the) table                            |
| a_notation                     | in     | text       | The "view identifier character" (default is "v")   |

*/
DECLARE
    l_notation text ;
BEGIN
    l_notation := coalesce ( a_notation, 'v' ) ;

    -- Tables that have a type designation prefix
    IF a_table_name ~ '^([a-z])t_' THEN
        RETURN regexp_replace ( a_table_name, '^([[a-z])t_', '\1' || l_notation || '_' ) ;
    END IF ;

    -- Tables that have no type designation prefix
    RETURN l_notation || '_' || a_table_name ;
END ;
$$ ;
