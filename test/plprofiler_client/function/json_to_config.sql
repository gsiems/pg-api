
CREATE OR REPLACE FUNCTION plprofiler_client.json_to_config (
    a_json json )
RETURNS plprofiler_client.ut_config
LANGUAGE plpgsql
AS $function$
DECLARE

    l_config plprofiler_client.ut_config ;
    r record ;

BEGIN

    FOR r IN (
        SELECT name,
                title,
                svg_width,
                table_width,
                tabstop,
                "desc"
            FROM json_populate_record ( null::plprofiler_client.ut_config, a_json ) ) LOOP

            l_config.name := r.name ;
            l_config.title := r.title ;
            l_config.svg_width := r.svg_width ;
            l_config.table_width := r.table_width ;
            l_config.tabstop := r.tabstop ;
            l_config."desc" := r."desc" ;

    END LOOP ;

    RETURN l_config ;

END ;
$function$;
