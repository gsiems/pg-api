/* *
## Drop roles

[002_drop_roles](002_drop_roles.sql)

*/

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

\unset ON_ERROR_STOP

DROP ROLE IF EXISTS example_db_developer ;
DROP USER IF EXISTS example_db_logger ;
DROP USER IF EXISTS example_db_bend ;
DROP USER IF EXISTS example_db_read ;
DROP USER IF EXISTS example_db_updt ;
DROP ROLE IF EXISTS example_db_owner ;

\set ON_ERROR_STOP
