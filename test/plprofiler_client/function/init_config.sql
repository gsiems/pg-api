
CREATE OR REPLACE FUNCTION plprofiler_client.init_config (
    a_opt_name text DEFAULT NULL::text,
    a_title text DEFAULT NULL::text,
    a_svg_width text DEFAULT NULL::text,
    a_table_width text DEFAULT NULL::text,
    a_tabstop smallint DEFAULT NULL::smallint,
    a_desc text DEFAULT NULL::text )
RETURNS plprofiler_client.ut_config
LANGUAGE plpgsql
AS $function$
DECLARE

    l_config plprofiler_client.ut_config ;

BEGIN

    l_config.name := a_opt_name ;
    l_config.title := coalesce ( a_title, concat_ws ( ' ', 'PL Profiler Report for', l_config.name ) ) ;
    l_config.svg_width := coalesce ( a_svg_width, '1200' ) ;
    l_config.table_width := coalesce ( a_svg_width, '80%' ) ;
    l_config.tabstop := coalesce ( a_tabstop, 8 ) ;

    l_config."desc" := concat ( '<h1>', l_config.title, E'</h1>\n<p>\n', coalesce ( a_desc, '<!-- description here -->' ), E'\n</p>' ) ;

    RETURN l_config ;

END ;
$function$;
