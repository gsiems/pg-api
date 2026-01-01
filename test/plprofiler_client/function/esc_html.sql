CREATE OR REPLACE FUNCTION plprofiler_client.esc_html (
    a_string text )
RETURNS text
LANGUAGE SQL
AS $$
/**
Function esc_html escapes HTML characters

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_string                       | in     | text       | The text to escape                                 |

*/

SELECT replace (
            replace (
                replace (
                    replace (
                        replace ( replace ( replace ( a_string, '&', '&amp;' ), '>', '&gt;' ), '<', '&lt;' ),
                        '"',
                        '&quot;' ),
                    '''',
                    '&apos;' ),
                ' ',
                '&nbsp;' ),
            E'\t',
            repeat ( '&nbsp;', 4 ) ) ;
$$ ;
