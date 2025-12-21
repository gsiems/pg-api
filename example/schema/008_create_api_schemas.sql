/**
## Create the API schemas

[008_create_api_schemas](008_create_api_schemas.sql)

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;


\i 301_create-priv_example_admin.sql
\i 302_create-example_admin.sql
