CREATE OR REPLACE FUNCTION util_meta.table_noun (
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function table_noun guesses at the proper "noun" for a table, view, or materialized view

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_name                  | in     | text       | The (name of the) table                            |
| a_ddl_schema                   | in     | text       | The (name of the) schema where whatever function/procedure is being created in |

*/
DECLARE

    l_base_schema text ;
    l_base_object text ;

BEGIN

    l_base_schema := util_meta.base_name ( a_ddl_schema ) ;
    l_base_object := regexp_replace ( a_object_name, '^[a-z][mtv]_', '' ) ;
    RETURN regexp_replace ( l_base_object, '^' || l_base_schema || '_', '' ) ;

END ;
$$ ;
