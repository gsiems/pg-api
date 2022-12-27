CREATE OR REPLACE FUNCTION util_meta.cleanup_whitespace (
    a_text text default null )
RETURNS text
LANGUAGE plpgsql stable
SECURITY DEFINER
AS $$
/**
Function cleanup_whitespace cleans up any excess white space from the specified text

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_text                         | in     | text       | The text to clean up                               |

*/
DECLARE

    l_result text ;

BEGIN

    -- replace trailing white-space
    l_result := regexp_replace ( a_text, E'[ \t](\n)', E'\n', 'g' ) ;

    -- replace excess vertical space
    l_result := regexp_replace ( l_result, E'\n\n\n+', E'\n\n', 'g' ) ;

    -- replace any excess closing vertical space
    l_result := regexp_replace ( l_result, E'\n\n+\$', E'\n' ) ;

    RETURN l_result ;

END ;
$$ ;
