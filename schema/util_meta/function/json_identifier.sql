CREATE OR REPLACE FUNCTION util_meta.json_identifier (
    a_identifier text )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function json_identifier takes a snake-cased database identifier (table name, column name, etc. ) and returns the (lower) camelCase form of the identifier

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_identifier                   | in     | text       | The identifier to transform                        |

| Input             | Output            |
| ----------------- | ----------------- |
| id                | id                |
| my_snazzy_id      | mySnazzyId        |

ASSERTIONS
    * all identifiers consist only of alpha [a-z], digits [0-9], and the underscore "_"

*/
DECLARE

    l_tokens text[] ;
    l_token text ;

BEGIN

    l_tokens := '{}'::text[] ;

    FOREACH l_token IN ARRAY string_to_array ( a_identifier, '_' ) LOOP

        IF cardinality ( l_tokens ) = 0 THEN
            l_tokens := array_append ( l_tokens, lower ( l_token ) ) ;
        ELSE
            l_tokens := array_append ( l_tokens, initcap ( l_token ) ) ;
        END IF ;

    END LOOP ;

    RETURN array_to_string ( l_tokens, '' ) ;

END ;
$$ ;
