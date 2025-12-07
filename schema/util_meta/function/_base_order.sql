CREATE OR REPLACE FUNCTION util_meta._base_order (
    a_object_name text DEFAULT NULL,
    a_base_name text DEFAULT NULL )
RETURNS integer
LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _base_order determines an ORDER BY value for the specified object and base names

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_name                  | in     | text       |     |
| a_base_name                    | in     | text       |     |

*/
SELECT CASE
            WHEN a_object_name IS NOT DISTINCT FROM a_base_name THEN 10
            WHEN a_object_name = 'priv_' || a_base_name THEN 20
            WHEN a_object_name = '_' || a_base_name THEN 30
            WHEN a_object_name = a_base_name || '_priv' THEN 40
            ELSE 50
            END ;
$$ ;
