CREATE OR REPLACE FUNCTION util_meta.guess_private_proc (
    a_proc_schema text DEFAULT NULL,
    a_table_noun text DEFAULT NULL,
    a_action text DEFAULT NULL )
RETURNS util_meta.ut_proc
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function guess_private_proc searches for an existing "private" procedure for an API procedure.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_proc_schema                  | in     | text       | The (name of the) schema that contains the public procedure |
| a_table_noun                   | in     | text       | The "noun" for table that the public procedure is for |
| a_action                       | in     | text       | The action that the generated function or procedure should perform {insert, update, upsert, delete} |

*/

/*
business_object_name [BON] (a_table_noun)
ACTION in {insert,update,delete,upsert} (a_action)
SCHEMA in {BON, API schema} (a_proc_schema)

- [SCHEMA].[ACTION]_[BON]

    could be any of:
    - [SCHEMA].priv_[ACTION]_[BON]
    - [SCHEMA]._[ACTION]_[BON]
    - priv_[SCHEMA].priv_[ACTION]_[BON]
    - priv_[SCHEMA]._[ACTION]_[BON]
    - priv_[SCHEMA].[ACTION]_[BON]
    - _[SCHEMA].priv_[ACTION]_[BON]
    - _[SCHEMA]._[ACTION]_[BON]
    - _[SCHEMA].[ACTION]_[BON]

    default to?
*/

DECLARE

    r record ;

    l_ret util_meta.ut_proc ;
    pfxary text[] := array[''::text,
        '_'::text,
        'priv_'::text] ;
    pfxs text ; -- schema prefix
    pfxp text ; -- procedure prefix

BEGIN

    -- Search for a pre-existing "private" procedure that matches
    FOREACH pfxs IN array pfxary LOOP

        FOREACH pfxp IN array pfxary LOOP

            IF pfxs != '' OR pfxp != '' THEN

                FOR r IN (
                    WITH args AS (
                        SELECT a_proc_schema AS proc_schema,
                                a_table_noun AS table_noun,
                                a_action AS action,
                                pfxs || a_proc_schema AS proc_schema_1,
                                pfxs || a_table_noun AS proc_schema_2,
                                pfxp || a_action || '_' || a_table_noun AS proc_name
                    )
                    SELECT schema_name,
                            object_name,
                            full_object_name,
                            object_type
                        FROM util_meta.objects
                        WHERE object_type IN ( 'function', 'procedure' )
                            AND object_name = args.proc_name
                            AND schema_name IN ( args.proc_schema_1, args.proc_schema_2 ) ) LOOP

                    l_ret.schema := r.schema_name ;
                    l_ret.name := r.object_name ;
                    l_ret.full_name := r.full_object_name ;
                    l_ret.type := r.object_type ;

                    RETURN l_ret ;

                END LOOP ;

            END IF ;

        END LOOP ;

    END LOOP ;

    -- Set/return the default
    l_ret.schema := a_proc_schema ;
    l_ret.name := concat_ws (
        '_',
        'priv',
        a_action,
        a_table_noun ) ;
    l_ret.full_name := concat_ws ( '.', l_ret.schema, l_ret.name ) ;
    l_ret.type := 'procedure' ;

    RETURN l_ret ;

END ;
$$ ;
