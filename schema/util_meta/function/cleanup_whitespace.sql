CREATE OR REPLACE FUNCTION util_meta.cleanup_whitespace (
    a_text text default null )
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
AS $$
/**
Function cleanup_whitespace cleans up any excess white space from the specified text

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_text                         | in     | text       | The text to clean up                               |

*/
DECLARE

    l_result text ;

BEGIN

    -- remove trailing tab and/or space characters
    l_result := regexp_replace ( a_text, E'[ \t](\n)', E'\n', 'g' ) ;

    -- remove excess vertical space
    l_result := regexp_replace ( l_result, E'\n\n\n+', E'\n\n', 'g' ) ;

    -- remove any excess closing vertical space
    l_result := regexp_replace ( l_result, E'\n\n+\$', E'\n' ) ;

    RETURN l_result ;

END ;
$$ ;
