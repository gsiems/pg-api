CREATE OR REPLACE FUNCTION plprofiler_client.init_config (
    a_opt_name text DEFAULT NULL::text,
    a_title text DEFAULT NULL::text,
    a_svg_width text DEFAULT NULL::text,
    a_table_width text DEFAULT NULL::text,
    a_tabstop smallint DEFAULT NULL::smallint,
    a_desc text DEFAULT NULL::text )
RETURNS plprofiler_client.ut_config
LANGUAGE plpgsql
AS $$
/**
Function init_config

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_opt_name                     | in     | text       | The name of the dataset                            |
| a_title                        | in     | text       | not used by plprofiler_client                      |
| a_svg_width                    | in     | text       | not used by plprofiler_client                      |
| a_table_width                  | in     | text       | not used by plprofiler_client                      |
| a_tabstop                      | in     | smallint   | not used by plprofiler_client                      |
| a_desc                         | in     | text       | not used by plprofiler_client                      |

*/
DECLARE

    l_config plprofiler_client.ut_config ;

BEGIN

    l_config.name := a_opt_name ;
    l_config.title := coalesce ( a_title, format ( 'PL Profiler Report for %s', l_config.name ) ) ;
    l_config.svg_width := coalesce ( a_svg_width, '1200' ) ;
    l_config.table_width := coalesce ( a_svg_width, '80%' ) ;
    l_config.tabstop := coalesce ( a_tabstop, 8 ) ;

    l_config."desc" := format (
        E'<h1>%s</h1>\n<p>\n%s\n</p>',
        l_config.title,
        coalesce ( a_desc, '<!-- description here -->' ) ) ;

    RETURN l_config ;

END ;
$$ ;
