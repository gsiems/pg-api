
CREATE OR REPLACE FUNCTION plprofiler_client.config_to_json (
    a_config plprofiler_client.ut_config )
RETURNS json
LANGUAGE plpgsql
AS $function$
BEGIN

    RETURN json_build_object (
        'name', a_config.name,
        'title', a_config.title,
        'svg_width', a_config.svg_width,
        'table_width', a_config.table_width,
        'tabstop', a_config.tabstop,
        'desc', a_config."desc" ) ;

END ;
$function$;
