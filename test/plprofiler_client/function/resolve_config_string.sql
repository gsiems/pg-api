
CREATE OR REPLACE FUNCTION plprofiler_client.resolve_config_string (
    a_opt_name text DEFAULT NULL::text,
    a_config plprofiler_client.ut_config DEFAULT NULL::plprofiler_client.ut_config,
    a_config_json json DEFAULT NULL::json )
RETURNS text
LANGUAGE plpgsql
AS $function$
DECLARE

    l_config_json json ;

BEGIN

    IF a_config_json IS NOT NULL THEN
        l_config_json := a_config_json ;
    ELSIF a_config IS NOT NULL THEN
        l_config_json := plprofiler_client.config_to_json ( a_config ) ;
    ELSE
        l_config_json := plprofiler_client.config_to_json ( plprofiler_client.init_config ( a_opt_name => a_opt_name ) ) ;
    END IF ;

    RETURN l_config_json::text ;

END ;
$function$;
