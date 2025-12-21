CREATE OR REPLACE FUNCTION util_meta._base_name (
    a_object_name text DEFAULT NULL )
RETURNS text
LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _base_name strips specific prefixes/suffixes from an object name to
determine its "base" name

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_name                  | in     | text       | The object name to determine a "base" name for     |

*/
SELECT regexp_replace ( regexp_replace ( a_object_name, '^(priv_|_)', '' ), '_(priv|json|api)$', '' ) AS base_name ;
$$ ;
