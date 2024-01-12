CREATE OR REPLACE FUNCTION util_meta.json_identifier (
    a_identifier text default null,
    a_json_casing text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function json_identifier takes a database identifier (table name, column name, etc. ) and
    returns the json identifier for the identifier

    (lower) camelCase form of the identifier

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_identifier                   | in     | text       | The identifier to transform                        |
| a_json_casing                  | in     | text       | The type of JSON casing to use {lowerCamel, upperCamel, snake} (defaults to lowerCamel) |

| Input             | JSON casing | Output            |
| ----------------- | ----------- | ----------------- |
| id                | lowerCamel  | id                |
| my_snazzy_id      | null        | mySnazzyId        |
| my_snazzy_id      | lowerCamel  | mySnazzyId        |
| my_snazzy_id      | upperCamel  | MySnazzyId        |
| my_snazzy_id      | snake       | my_snazzy_id      |

*/
DECLARE

    l_tokens text[] ;
    l_token text ;
    l_casing text ;
    l_identifier text ;
    l_separator text ;

BEGIN

    l_casing := coalesce ( util_meta.resolve_parameter (
                a_name => 'json_casing' ), 'lowerCamel' ) AS chars ;

    IF l_casing = 'snake' THEN
        l_separator := '_' ;
    ELSE
        l_separator := '' ;
    END IF ;

    l_tokens := '{}'::text[] ;

    l_identifier := regexp_replace ( a_identifier, '[^\w]', '_', 'g' ) ;

    -- some form of camel case
    FOREACH l_token IN ARRAY string_to_array ( l_identifier, '_' ) LOOP

        IF l_token IS NULL OR l_token = '' THEN
            null;

        ELSIF l_casing = 'snake' THEN

            l_tokens := array_append ( l_tokens, lower ( l_token ) ) ;

        ELSIF l_casing = 'upperCamel' THEN

            l_tokens := array_append ( l_tokens, initcap ( l_token ) ) ;

        ELSE -- lowerCamel

            IF cardinality ( l_tokens ) = 0 THEN
                l_tokens := array_append ( l_tokens, lower ( l_token ) ) ;
            ELSE
                l_tokens := array_append ( l_tokens, initcap ( l_token ) ) ;
            END IF ;

        END IF ;

    END LOOP ;

    RETURN array_to_string ( l_tokens, l_separator ) ;

END ;
$$ ;
