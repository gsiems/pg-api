CREATE OR REPLACE FUNCTION util_meta._to_plural (
    a_term text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _to_plural attempts to return the plural form of a term

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_term                         | in     | text       | The term to pluralize                              |

*/
DECLARE

    r record ;
    l_token text ;
    l_tokens text[] ;

BEGIN

    l_tokens := string_to_array ( a_term, '_' ) ;
    IF cardinality ( l_tokens ) > 0 THEN
        l_token := l_tokens[array_upper ( l_tokens, 1 )] ;

        FOR r IN (
            SELECT plural_form
                FROM util_meta.rt_plural_word
                WHERE word = l_token ) LOOP

            l_tokens[array_upper ( l_tokens, 1 )] := r.plural_form ;

        END LOOP ;

        RETURN array_to_string ( l_tokens, '_' ) ;

    END IF ;

    RETURN a_term ;

END ;
$$ ;
