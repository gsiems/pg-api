CREATE OR REPLACE FUNCTION util_meta._to_singular (
    a_term text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _to_singular attempts to return the singular form of a term

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_term                         | in     | text       | The term to convert to singular form               |

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
            SELECT word
                FROM util_meta.rt_plural_word
                WHERE plural_form = l_token ) LOOP

            l_tokens[array_upper ( l_tokens, 1 )] := r.word ;

        END LOOP ;

        RETURN array_to_string ( l_tokens, '_' ) ;

    END IF ;

    RETURN a_term ;

END ;
$$ ;
