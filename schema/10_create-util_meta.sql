
DROP SCHEMA util_meta CASCADE ;

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = on ;
SET check_function_bodies = true ;
SET client_min_messages = warning ;

CREATE SCHEMA IF NOT EXISTS util_meta ;

COMMENT ON SCHEMA util_meta IS 'Database meta-data for objects (views, functions, procedures) for creating database API objects.' ;

-- Views -----------------------------------------------------------------------
\i util_meta/view/schemas.sql
\i util_meta/view/objects.sql
\i util_meta/view/columns.sql
\i util_meta/view/foreign_keys.sql
\i util_meta/view/object_grants.sql

-- Functions -------------------------------------------------------------------

-- Common utility functions
\i util_meta/function/indent.sql
\i util_meta/function/is_valid_object.sql
\i util_meta/function/new_line.sql
\i util_meta/function/table_noun.sql

-- Snippet functions
\i util_meta/function/snippet_declare_params.sql
\i util_meta/function/snippet_documentation_block.sql
\i util_meta/function/snippet_function_backmatter.sql
\i util_meta/function/snippet_function_frontmatter.sql
\i util_meta/function/snippet_object_comment.sql
\i util_meta/function/snippet_owners_and_grants.sql

\i util_meta/function/snippet_get_permissions.sql

-- "Final" DDL generating functions
\i util_meta/function/mk_view.sql
\i util_meta/function/mk_user_type.sql
\i util_meta/function/mk_table_migration.sql

\i util_meta/function/mk_resolve_id_function.sql

\i util_meta/function/mk_find_function.sql
