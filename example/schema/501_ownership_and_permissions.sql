/**
## Ownership and Permissions

[501_ownership_and_permissions](501_ownership_and_permissions.sql)

### Goal

To document rules regarding how ownership/privileges could be set and provide
code to enforce those rules.

### Approach

Rather than setting object ownership and permissions in each individual DDL
file the setting of ownership and permissions could be consolidated into one
location... here.

### Rule Basics

1. All database objects should be owned by the same owner. In the example the
"example_db_owner" role should be the owner of all objects (In a real
application it is hoped that the owner is not named "example_db_owner"). Also,
in a real application, there may be exceptions to this rule and those
exceptions should be documented-- for example, if the database integrates some
third-party tools such as ESRI).

2. The database objects owner should be a NOLOGIN role.

3. The database objects owner should be consistent across the different
environments (local, development, test, and production).

4. Permissions to "private" objects should be minimized and should be
consistently applied across the different environments.

5. Permissions to API objects should be should be consistently applied across
the different environments.

6. Grants to the "public" role should be minimized.

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;


