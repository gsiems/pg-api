/**
## Create roles

[003_create_roles](003_create_roles.sql)

*/

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

\unset ON_ERROR_STOP

CREATE ROLE example_db_owner NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE example_db_owner IS 'Default ownership role for all example_db database objects' ;

CREATE USER example_db_bend NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE example_db_bend IS 'Back-end maintenance role for the example_db database' ;

CREATE USER example_db_logger NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE example_db_logger IS 'Logging role for the example_db database' ;

CREATE USER example_db_read NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE example_db_read IS 'Read-only role for the example_db database' ;

CREATE USER example_db_updt NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE example_db_updt IS 'Update role for the example_db database' ;

CREATE ROLE example_db_developer NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE example_db_developer IS 'Developer role for working with the example_db database' ;

GRANT example_db_read TO example_db_developer ;
GRANT example_db_updt TO example_db_developer ;

\set ON_ERROR_STOP
