
DROP SCHEMA IF EXISTS util_meta CASCADE ;

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = on ;
SET check_function_bodies = true ;
SET client_min_messages = warning ;

CREATE SCHEMA IF NOT EXISTS util_meta ;

COMMENT ON SCHEMA util_meta IS 'Database meta-data for objects (views, functions, procedures) for creating database API objects.' ;


-- Types -----------------------------------------------------------------------
\i util_meta/type/ut_parameters.sql

-- Tables ----------------------------------------------------------------------
\i util_meta/table/st_default_param.sql
\i util_meta/table/rt_config_default.sql

-- Views -----------------------------------------------------------------------
\i util_meta/view/conftypes.sql
\i util_meta/view/contypes.sql
\i util_meta/view/prokinds.sql
\i util_meta/view/relkinds.sql
\i util_meta/view/typtypes.sql

\i util_meta/view/schemas.sql
\i util_meta/view/objects.sql
\i util_meta/view/columns.sql
\i util_meta/view/foreign_keys.sql
\i util_meta/view/object_grants.sql
\i util_meta/view/dependencies.sql

-- Functions -------------------------------------------------------------------

-- Common utility functions
\i util_meta/function/resolve_parameter.sql

\i util_meta/function/append_parameter.sql

\i util_meta/function/cleanup_whitespace.sql
\i util_meta/function/indent.sql
\i util_meta/function/is_valid_object.sql
\i util_meta/function/new_line.sql
\i util_meta/function/table_noun.sql
\i util_meta/function/proc_parameters.sql
\i util_meta/function/calling_parameters.sql
\i util_meta/function/boolean_casting.sql

-- Snippet functions
\i util_meta/function/snippet_declare_variables.sql
\i util_meta/function/snippet_documentation_block.sql

\i util_meta/function/snippet_log_params.sql
\i util_meta/function/snippet_object_comment.sql
\i util_meta/function/snippet_owners_and_grants.sql
\i util_meta/function/snippet_resolve_id.sql
\i util_meta/function/snippet_resolve_user_id.sql

\i util_meta/function/snippet_function_backmatter.sql
\i util_meta/function/snippet_function_frontmatter.sql
\i util_meta/function/snippet_procedure_backmatter.sql
\i util_meta/function/snippet_procedure_frontmatter.sql

\i util_meta/function/snippet_get_permissions.sql
\i util_meta/function/snippet_permissions_check.sql

--------------------------------------------------------------------------------
-- "Final" DDL generating functions for "regular API" objects
\i util_meta/function/mk_view.sql
\i util_meta/function/mk_user_type.sql
\i util_meta/function/mk_object_migration.sql

\i util_meta/function/mk_resolve_id_function.sql
\i util_meta/function/mk_can_do_function_shell.sql

\i util_meta/function/mk_find_function.sql
\i util_meta/function/mk_get_function.sql
\i util_meta/function/mk_list_function.sql

\i util_meta/function/mk_priv_delete_procedure.sql
\i util_meta/function/mk_priv_insert_procedure.sql
\i util_meta/function/mk_priv_update_procedure.sql

\i util_meta/function/mk_delete_procedure.sql
\i util_meta/function/mk_insert_procedure.sql
\i util_meta/function/mk_update_procedure.sql

--------------------------------------------------------------------------------
-- JSON utility functions
\i util_meta/function/json_identifier.sql

-- JSON snippet functions
\i util_meta/function/snippet_json_agg_build_object.sql
\i util_meta/function/snippet_json_build_object.sql

-- "Final" DDL generating functions for "JSON API" objects
\i util_meta/function/mk_json_view.sql
\i util_meta/function/mk_json_user_type.sql

\i util_meta/function/mk_json_function_wrapper.sql

--------------------------------------------------------------------------------
-- Testing functions
--\i util_meta/function/mk_test_procedure_wrapper.sql
