/**
## Create the utility schemas

[006_create_util_schemas](006_create_util_schemas.sql)

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

\i 101_create-util_log.sql
\i 102_create-util_meta.sql
