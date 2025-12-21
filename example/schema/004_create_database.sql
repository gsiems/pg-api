/**
## Create the database

[004_create_database](004_create_database.sql)

*/

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

\unset ON_ERROR_STOP

CREATE DATABASE example_db
    WITH TEMPLATE = template0
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8' ;

COMMENT ON DATABASE example_db IS 'example_db database.' ;

ALTER DATABASE example_db OWNER TO example_db_owner ;

\set ON_ERROR_STOP

REVOKE ALL ON DATABASE example_db FROM PUBLIC ;

\connect example_db

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog ;

--CREATE EXTENSION IF NOT EXISTS postgis ;
--CREATE EXTENSION IF NOT EXISTS fuzzystrmatch ;
CREATE EXTENSION IF NOT EXISTS plpgsql_check ;
