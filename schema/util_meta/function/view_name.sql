CREATE OR REPLACE FUNCTION util_meta.view_name (
    a_table_name text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function view_name converts a table name to a view name

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_table_name                   | in     | text       | The (name of the) table                            |

*/
BEGIN
    IF a_table_name ~ '^([a-z])t_' THEN
        RETURN regexp_replace ( a_table_name, '^([drs])t_', '\1v_' ) ;
    END IF ;
    RETURN 'v_' || a_table_name ;
END ;
$$ ;
