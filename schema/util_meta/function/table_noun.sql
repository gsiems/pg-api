CREATE OR REPLACE FUNCTION util_meta.table_noun (
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL )
RETURNS text
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function table_noun guesses at the proper "noun" for a table (or view)

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_name                  | in     | text       | The (name of the) table                            |
| a_ddl_schema                   | in     | text       | The (name of the) schema where whatever function/procedure is being created in |

*/

WITH x AS (
    SELECT replace (
                replace ( replace ( replace ( a_ddl_schema, '_json', '' ), '_priv$', '' ), '^priv_', '' ),
                '^_',
                '' ) AS ddl_schema
)
SELECT regexp_replace ( regexp_replace ( a_object_name, '^[drs][tv]_', '' ), '^' || ddl_schema || '_', '' )
    FROM x ;

$$ ;
