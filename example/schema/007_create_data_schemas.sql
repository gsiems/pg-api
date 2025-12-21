/**
## Create the data schemas

[007_create_data_schemas](007_create_data_schemas.sql)

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;


\i 201_create-example_data.sql
