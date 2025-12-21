CREATE OR REPLACE FUNCTION util_log.dici (
    a_arg anyelement )
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_log
AS $$
/**

Function dici (Italian for "you say") takes an input and converts it to a text output. In the
case of a character/text input it also adds proper quoting.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_arg                          | in     | anyelement | The item to be cast to text.                       |

*/
DECLARE

    l_datatype text ;
    l_trim_length integer := 1000 ;

BEGIN

    IF a_arg IS NULL THEN
        RETURN 'null'::text ;
    END IF ;

    l_datatype := pg_typeof ( a_arg )::text ;

    IF l_datatype = 'text' OR l_datatype LIKE '%character%' THEN
        IF length ( a_arg::text ) > l_trim_length THEN
            RETURN quote_literal ( substr ( a_arg::text, 1, l_trim_length ) || '...'::text ) ;
        ELSE
            RETURN quote_literal ( a_arg::text ) ;
        END IF ;
    END IF ;

    RETURN a_arg::text ;

END ;
$$ ;
