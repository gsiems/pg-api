
SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = on ;
SET check_function_bodies = true ;
SET client_min_messages = warning ;


CREATE SCHEMA IF NOT EXISTS plprofiler ;

CREATE EXTENSION IF NOT EXISTS plprofiler SCHEMA plprofiler ;

ALTER SCHEMA plprofiler OWNER TO plprofiler ;

CREATE SCHEMA IF NOT EXISTS plprofiler_client AUTHORIZATION plprofiler ;

COMMENT ON SCHEMA plprofiler_client IS 'Functions extracted from the plprofiler client tool (with some modifications)' ;

/* TODO: evaluate extraction/conversion of
    - get_local_report_data
    - get_shared_report_data
    - save_dataset_from_report
*/

\i type/ut_config.sql

\i function/esc_html.sql
\i function/init_config.sql
\i function/json_to_config.sql
\i function/config_to_json.sql
\i function/resolve_config_string.sql

\i function/query_plprofiler_namespace.sql
\i function/get_profiler_namespace.sql
\i function/set_search_path.sql

\i function/get_dataset_config.sql
\i function/update_dataset_config.sql

\i function/get_dataset_list.sql
\i function/delete_dataset.sql

\i function/disable.sql
\i function/enable.sql

\i function/disable_monitor.sql
\i function/enable_monitor.sql

\i function/reset_local.sql
\i function/reset_shared.sql

\i function/save_collect_data.sql
\i function/save_dataset_from_local.sql
\i function/save_dataset_from_shared.sql

\i function/init_profile.sql
\i function/generate_coverage_report.sql
\i function/generate_profiler_report.sql

GRANT USAGE ON SCHEMA plprofiler_client TO session_user ;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA plprofiler_client TO session_user WITH GRANT OPTION ;
