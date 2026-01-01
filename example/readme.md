# An Example

As the user account table is the only table `util_meta` expects to exist, that
is the table (`dt_user`) that the example is based on.

Order is important. Since the goal is to use metadata to draft/create DDL for
the various database objects, and the DDL generated in a step usually depends
on the metadata for objects that were generated in a previous step.

At each step, the generated DDL may require review and adjustments prior to
using the DDL to create the database object(s).

Starting with an almost empty schema directory, containing only the desired
utility schemas:

```
ls -1 schema
    util_log
    util_meta
```

## Create the database and database roles

Run `init_database_scripts` to initialize the sql files in the schema directory
for creating the database, database roles, and util_* schema creation scripts.

```
../util/schema_tools/init_database_scripts.sh -d example_db -o "${PWD}"/schema
```

After checking over the generated files, run them to create the database and
database roles.

```
schema/000_run_all.sh
```

NB: The intent is that running `000_run_all.sh` at any point will drop and
recreate the database to include all existing schema creations scripts. This is
intended for use by developers on their personal development environments (or
for initializing new environments) and is not recommended for existing
non-development environments.

## Create the data schema scripts and directories

Run `init_schema_scripts` to create the scripts and directory structure for the
data schema.

```
../util/schema_tools/init_schema_scripts.sh -t data -s example_data -o "${PWD}"/schema
```

Create the tables. NB: this is for the simplest app that could possibly work.

Create and edit:
 * [`schema/example_data/sequence/seq_rt_id.sql`](schema/example_data/sequence/seq_rt_id.sql)
 * [`schema/example_data/table/st_app_role.sql`](schema/example_data/table/st_app_role.sql)
 * [`schema/example_data/table/dt_user.sql`](schema/example_data/table/dt_user.sql)
 * [`schema/example_data/table/dt_user_app_role.sql`](schema/example_data/table/dt_user_app_role.sql)

Note that the tables and columns all have comments.

Run the `reconcile_source_files` to add the table (and sequence) files to the
"create example_data schema"
([`201_create-example_data.sql`](schema/201_create-example_data.sql)) psql
script. This will add any new files to the end of the file (this will also
comment out any listed files that no longer exist).

```
../util/schema_tools/reconcile_source_files.sh -o "${PWD}"/schema
```

Edit the `schema/201_create-example_data.sql` psql script to ensure the tables
are created in the correct order and then run the script to create the schema
and tables in the database.

```
(cd schema && psql -f 201_create-example_data.sql)
```

## Create the API schema scripts and directory structure

Run `init_schema_scripts` to create the scripts and directory structure for the
API schemas.

```
../util/schema_tools/init_schema_scripts.sh -t api -s priv_example_admin,example_admin -o "${PWD}"/schema
```

Run the generated plspl scripts to create the API schemas.

```
(cd schema && psql -f 301_create-priv_example_admin.sql)
(cd schema && psql -f 302_create-example_admin.sql)
```

## Create views

NB: the `generators.sh` script contains wrappers for various `util_meta`
functions and is used for generating source DDL files. For the purposes of this
example, the files are created under an `as_generated` directory. After
generating the files they are manually copied to the correct schema directory
before making any desired edits. Keeping a separate "as generated" version of
the files allows for comparisons between the generated and final code.

Running:

```
../util/schema_tools/mk_view.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --ddl_schema priv_example_admin \
    --object_schema example_data \
    --object_name st_app_role \
    --verbose

../util/schema_tools/mk_view.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --ddl_schema priv_example_admin \
    --object_schema example_data \
    --object_name dt_user \
    --verbose

../util/schema_tools/mk_view.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --ddl_schema priv_example_admin \
    --object_schema example_data \
    --object_name dt_user_app_role \
    --verbose
```

Executes the following to generate sql files for creating the views:

```
SELECT util_meta.mk_view (
        a_object_schema => 'example_data'::text,
        a_object_name => 'st_app_role'::text,
        a_ddl_schema => 'priv_example_admin'::text,
        a_cast_booleans_as => null::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;

SELECT util_meta.mk_view (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'priv_example_admin'::text,
        a_cast_booleans_as => null::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;

SELECT util_meta.mk_view (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user_app_role'::text,
        a_ddl_schema => 'priv_example_admin'::text,
        a_cast_booleans_as => null::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;
```

Copy the generated files.

```
cp schema/as_generated/priv_example_admin/view/*.sql schema/priv_example_admin/view/
```

Edit the copied files as needed. Note how the table comments were used for
generating the view comments.
 * [`schema/priv_example_admin/view/sv_app_role.sql`](schema/priv_example_admin/view/sv_app_role.sql)
 * [`schema/priv_example_admin/view/dv_user.sql`](schema/priv_example_admin/view/dv_user.sql)
 * [`schema/priv_example_admin/view/dv_user_app_role.sql`](schema/priv_example_admin/view/dv_user_app_role.sql)

Run the `reconcile_source_files` script to add the view DDL files to the
([`301_create-priv_example_admin`](schema/301_create-priv_example_admin)) psql
script.

```
../util/schema_tools/reconcile_source_files.sh -o "${PWD}"/schema
```

Edit `schema/301_create-priv_example_admin.sql` to ensure the views are created
in the correct order and then run the script to create the views in the
database.

```
(cd schema && psql -f 301_create-priv_example_admin.sql)
```

## Create the private `resolve_user_id` function

Before creating the private procedures for updating the data the resolve ID
function(s) need to be created.

Running:

```
../util/schema_tools/mk_resolve_id_function.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --ddl_schema priv_example_admin \
    --object_schema example_data \
    --object_name dt_user \
    --verbose
```

Executes the following to generate the sql file for creating the
`resolve_user_id` function:

```
SELECT util_meta.mk_resolve_id_function (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'priv_example_admin'::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;
```

Copy the generated file.

```
cp schema/as_generated/priv_example_admin/function/resolve_user_id.sql schema/priv_example_admin/function/
```

Edit the copied file as needed.

Once again, run

```
../util/schema_tools/reconcile_source_files.sh -o "${PWD}"/schema
```

then edit and run `301_create-priv_example_admin.sql` to create the function.

```
(cd schema && psql -f 301_create-priv_example_admin.sql)
```

## Create the private procedures

By now, a pattern should be seen...

```
../util/schema_tools/mk_priv_insert_procedure.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --ddl_schema priv_example_admin \
    --object_schema example_data \
    --object_name dt_user \
    --verbose

../util/schema_tools/mk_priv_update_procedure.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --ddl_schema priv_example_admin \
    --object_schema example_data \
    --object_name dt_user \
    --verbose

../util/schema_tools/mk_priv_upsert_procedure.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --ddl_schema priv_example_admin \
    --object_schema example_data \
    --object_name dt_user \
    --verbose
```

```
SELECT util_meta.mk_priv_insert_procedure (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'priv_example_admin'::text,
        a_cast_booleans_as => null::text,
        a_insert_audit_columns => 'created_dt,created_by_id'::text,
        a_update_audit_columns => 'updated_dt,updated_by_id'::text,
        a_owner => null::text
        ) ;

SELECT util_meta.mk_priv_update_procedure (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'priv_example_admin'::text,
        a_cast_booleans_as => null::text,
        a_insert_audit_columns => 'created_dt,created_by_id'::text,
        a_update_audit_columns => 'updated_dt,updated_by_id'::text,
        a_owner => null::text
        ) ;

SELECT util_meta.mk_priv_upsert_procedure (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'priv_example_admin'::text,
        a_cast_booleans_as => null::text,
        a_insert_audit_columns => 'created_dt,created_by_id'::text,
        a_update_audit_columns => 'updated_dt,updated_by_id'::text,
        a_owner => null::text
        ) ;
```

```
cp schema/as_generated/priv_example_admin/procedure/* schema/priv_example_admin/procedure/
```

Before editing the copied files we want to create a non-generated procedure
(`schema/priv_example_admin/procedure/priv_set_user_app_roles.sql`) for
managing the dt_user_app_role data:

Edit
 * [schema/priv_example_admin/procedure/priv_update_user.sql](schema/priv_example_admin/procedure/priv_update_user.sql)
 * [schema/priv_example_admin/procedure/priv_upsert_user.sql](schema/priv_example_admin/procedure/priv_upsert_user.sql)
 * [schema/priv_example_admin/procedure/priv_insert_user.sql](schema/priv_example_admin/procedure/priv_insert_user.sql)
to include calls to the priv_set_user_app_roles procedure

Note how the database column comments were used in generating the documentation
block at the top of the procedures.

Update the `301_create-priv_example_admin.sql` file

```
../util/schema_tools/reconcile_source_files.sh -o "${PWD}"/schema
```

Edit and run `schema/301_create-priv_example_admin.sql` to ensure that the
schema objects are created in the proper order.

```
(cd schema && psql -f 301_create-priv_example_admin.sql)
```

## Create the `can_do` function(s)

Before creating the public API functions and procedures `can_do` function needs
to be created.

```
../util/schema_tools/mk_can_do_function_shell.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --ddl_schema example_data \
    --verbose
```

```
SELECT util_meta.mk_can_do_function_shell (
        a_ddl_schema => 'example_data'::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;
```

```
cp schema/as_generated/example_admin/function/can_do.sql schema/example_admin/function/
```

Edit ```schema/example_admin/function/can_do.sql```

```
../util/schema_tools/reconcile_source_files.sh -o "${PWD}"/schema
```

Edit and run ```schema/302_create-example_admin.sql```

```
(cd schema && psql -f 302_create-example_admin.sql)
```

## Create the API functions


```
../util/schema_tools/mk_find_function.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --object_schema example_data \
    --object_name dt_user \
    --ddl_schema example_admin \
    --verbose

../util/schema_tools/mk_get_function.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --object_schema example_data \
    --object_name dt_user \
    --ddl_schema example_admin \
    --verbose

../util/schema_tools/mk_list_function.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --object_schema example_data \
    --object_name dt_user \
    --ddl_schema example_admin \
    --verbose
```

```
SELECT util_meta.mk_find_function (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'example_admin'::text,
        a_is_row_based => null::boolean,
        a_owner => null::text,
        a_grantees => null::text
        ) ;

SELECT util_meta.mk_get_function (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'example_admin'::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;

SELECT util_meta.mk_list_function (
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'example_admin'::text,
        a_exclude_binary_data => null::boolean,
        a_owner => null::text,
        a_grantees => null::text
        ) ;
```

```
cp schema/as_generated/example_admin/function/get_user.sql schema/example_admin/function/
cp schema/as_generated/example_admin/function/find_users.sql schema/example_admin/function/
cp schema/as_generated/example_admin/function/list_users.sql schema/example_admin/function/
```

Edit:
 * [schema/example_admin/function/find_users.sql](schema/example_admin/function/find_users.sql)
 * [schema/example_admin/function/get_user.sql](schema/example_admin/function/get_user.sql)
 * [schema/example_admin/function/list_users.sql](schema/example_admin/function/list_users.sql)

Note how the database column comments were used in generating the documentation
block at the top of the procedures.

```
../util/schema_tools/reconcile_source_files.sh -o "${PWD}"/schema
```

Edit and run `schema/302_create-example_admin.sql`

```
(cd schema && psql -f 302_create-example_admin.sql)
```

## Create the API procedures

```
../util/schema_tools/mk_api_procedure.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --action insert \
    --object_schema example_data \
    --object_name dt_user \
    --ddl_schema example_admin \
    --verbose

../util/schema_tools/mk_api_procedure.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --action update \
    --object_schema example_data \
    --object_name dt_user \
    --ddl_schema example_admin \
    --verbose

../util/schema_tools/mk_api_procedure.sh \
    --dir "${PWD}"/schema/as_generated \
    --db example_db \
    --action upsert \
    --object_schema example_data \
    --object_name dt_user \
    --ddl_schema example_admin \
    --verbose
```

```
SELECT util_meta.mk_api_procedure (
        a_action => 'insert'::text,
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'example_admin'::text,
        a_cast_booleans_as => null::text,
        a_insert_audit_columns => 'created_dt,created_by_id'::text,
        a_update_audit_columns => 'updated_dt,updated_by_id'::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;

SELECT util_meta.mk_api_procedure (
        a_action => 'update'::text,
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'example_admin'::text,
        a_cast_booleans_as => null::text,
        a_insert_audit_columns => 'created_dt,created_by_id'::text,
        a_update_audit_columns => 'updated_dt,updated_by_id'::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;

SELECT util_meta.mk_api_procedure (
        a_action => 'upsert'::text,
        a_object_schema => 'example_data'::text,
        a_object_name => 'dt_user'::text,
        a_ddl_schema => 'example_admin'::text,
        a_cast_booleans_as => null::text,
        a_insert_audit_columns => 'created_dt,created_by_id'::text,
        a_update_audit_columns => 'updated_dt,updated_by_id'::text,
        a_owner => null::text,
        a_grantees => null::text
        ) ;
```

```
cp schema/as_generated/example_admin/procedure/* schema/example_admin/procedure/
```

Edit:
 * [schema/example_admin/procedure/update_user.sql](schema/example_admin/procedure/update_user.sql)
 * [schema/example_admin/procedure/insert_user.sql](schema/example_admin/procedure/insert_user.sql)
 * [schema/example_admin/procedure/upsert_user.sql](schema/example_admin/procedure/upsert_user.sql)

Note how the database column comments were used in generating the documentation
block at the top of the procedures.

```
../util/schema_tools/reconcile_source_files.sh -o "${PWD}"/schema
```

Edit and run ```schema/302_create-example_admin.sql```

```
(cd schema && psql -f 302_create-example_admin.sql)
```

## Run plpgsql_check

Run

```
../test/03_run_plpgsql_check.sh -d example_db
```

to lint the existing database functions and procedures. Note that, due to the
simplified nature of the `can_do` function in this example there will be some
complaints about unused calling parameters-- there should be no other errors
flagged.

## Compare generated vs edited code

```
$ cloc schema/priv_example_admin
       9 text files.
       9 unique files.
       0 files ignored.

github.com/AlDanial/cloc v 1.90  T=0.01 s (602.4 files/s, 37954.2 lines/s)
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
SQL                              9             81             82            404
-------------------------------------------------------------------------------
SUM:                             9             81             82            404
-------------------------------------------------------------------------------
```

```
$ cloc schema/example_admin
       7 text files.
       7 unique files.
       0 files ignored.

github.com/AlDanial/cloc v 1.90  T=0.02 s (365.6 files/s, 24442.6 lines/s)
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
SQL                              7             74             89            305
-------------------------------------------------------------------------------
SUM:                             7             74             89            305
-------------------------------------------------------------------------------
```

Looking at the line counts for the files comparing the as generated line counts
to the final line counts:

| Schema             | Type      | File Name                   | Generated | Edited | Delta | Percent |
| ------------------ | --------- | --------------------------- | --------- | ------ | ----- | ------- |
| priv_example_admin | function  | resolve_user_id.sql         |        60 |     60 |     0 |   0.00% |
| priv_example_admin | procedure | priv_insert_user.sql        |        88 |     97 |     9 |   9.28% |
| priv_example_admin | procedure | priv_set_user_app_roles.sql |       N/A |     77 |    77 |         |
| priv_example_admin | procedure | priv_update_user.sql        |        80 |     89 |     9 |  10.11% |
| priv_example_admin | procedure | priv_upsert_user.sql        |       116 |    125 |     9 |   7.20% |
| priv_example_admin | view      | dv_user_app_role.sql        |        28 |     28 |     0 |   0.00% |
| priv_example_admin | view      | dv_user.sql                 |        34 |     34 |     0 |   0.00% |
| priv_example_admin | view      | sv_app_role.sql             |        20 |     20 |     0 |   0.00% |
| example_admin      | function  | can_do.sql                  |        50 |     64 |    14 |  21.88% |
| example_admin      | function  | find_users.sql              |        57 |     57 |     0 |   0.00% |
| example_admin      | function  | get_user.sql                |        46 |     46 |     0 |   0.00% |
| example_admin      | function  | list_users.sql              |        38 |     38 |     0 |   0.00% |
| example_admin      | procedure | insert_user.sql             |        75 |     79 |     4 |   5.06% |
| example_admin      | procedure | update_user.sql             |        81 |     85 |     4 |   4.71% |
| example_admin      | procedure | upsert_user.sql             |        95 |     99 |     4 |   4.04% |
| **Totals**         |           |                           | **868** | **998** | **130** | **13.03%** |

## Create the JSON functions

TODO

## Create the JSON procedures

TODO

## Generate API documentation

```
mkdir -p doc/api
```

```
touch doc/conventions.md doc/glossary.md
```

```
echo "# Documentation

 - [Conventions](conventions.md)
 - [Database API](api/readme.md)
 - [Glossary of terms](glossary.md)
" > doc/readme.md
```

```
../util/doc/extract_api_doc.sh -d example_db -s "${PWD}"/schema -t "${PWD}"/doc/api
```

## Testing

### Setup some test data

Firstly, pre-load the database with some test data...

`cat test/test_data/001_dt_user.sql`
```
DELETE FROM example_data.dt_user_app_role ;
DELETE FROM example_data.dt_user ;

INSERT INTO example_data.dt_user ( username, first_name, last_name )
    VALUES
        ( session_user::text, initcap ( session_user::text ), 'NLN' ),
        ( 'alice', 'Alice', 'A' ),
        ( 'bob', 'Bob', 'B' ),
        ( 'eve', 'Eve', 'Eavesdropper' ),
        ( 'mallory', 'Mallory', 'Malicious' ),
        ( 'trent', 'Trent', 'Trusted' ) ;
```

`cat test/test_data/002_dt_user_app_role.sql`
```
DELETE FROM example_data.dt_user_app_role ;

WITH n AS (
    SELECT usr.id AS user_id,
            rol.id AS app_role_id
        FROM example_data.dt_user usr
        CROSS JOIN example_data.st_app_role rol
        WHERE rol.name = 'admin'
            AND usr.username IN ( session_user::text, 'trent' )
    UNION
    SELECT usr.id AS user_id,
            rol.id AS rol_id
        FROM example_data.dt_user usr
        CROSS JOIN example_data.st_app_role rol
        WHERE rol.name IN ( 'read', 'write' )
            AND usr.username IN ( 'alice', 'bob' )
    UNION
    SELECT usr.id AS user_id,
            rol.id AS rol_id
        FROM example_data.dt_user usr
        CROSS JOIN example_data.st_app_role rol
        WHERE rol.name = 'read'
            AND usr.username = 'eve'
)
INSERT INTO example_data.dt_user_app_role ( user_id, app_role_id )
    SELECT *
        FROM n ;
```

### Create the test wrapper functions

Before writing tests for the insert_user, update_user, and upsert_user
procedures it is first necessary to create wrapper functions that can translate
the success or failure of the procedures to a boolean true/false value that can
be used by pgTAP.

```
../util/schema_tools/mk_test_procedure_wrapper.sh \
    --dir "${PWD}"/test \
    --db example_db \
    --object_schema example_admin \
    --object_name insert_user \
    --test_schema test \
    --verbose

../util/schema_tools/mk_test_procedure_wrapper.sh \
    --dir "${PWD}"/test \
    --db example_db \
    --object_schema example_admin \
    --object_name update_user \
    --test_schema test \
    --verbose

../util/schema_tools/mk_test_procedure_wrapper.sh \
    --dir "${PWD}"/test \
    --db example_db \
    --object_schema example_admin \
    --object_name upsert_user \
    --test_schema test \
    --verbose
```

```
SELECT util_meta.mk_test_procedure_wrapper (
        a_object_schema => 'example_admin'::text,
        a_object_name => 'insert_user'::text,
        a_test_schema => 'test'::text
        ) ;

SELECT util_meta.mk_test_procedure_wrapper (
        a_object_schema => 'example_admin'::text,
        a_object_name => 'update_user'::text,
        a_test_schema => 'test'::text
        ) ;

SELECT util_meta.mk_test_procedure_wrapper (
        a_object_schema => 'example_admin'::text,
        a_object_name => 'upsert_user'::text,
        a_test_schema => 'test'::text
        ) ;
```

Note that, while wrappers for the priv_insert_user, priv_update_user, and
priv_upsert_user procedures could be created and used, there isn't much benefit
to doing so (in this example anyhow) as the private procedures will get tested
by virtue of testing the public procedures.

Add the the test wrappers to the test/10_init_testrun.sql file:

```
\i tests/example_admin/function/example_admin__insert_user.sql
\i tests/example_admin/function/example_admin__update_user.sql
\i tests/example_admin/function/example_admin__upsert_user.sql
```

### Create the PgTAP test files

`cat test/tests/example_admin/01_test_can_do.sql`
```
\i 20_pre_tap.sql

SELECT PLAN ( 4 ) ;

SELECT ok (
    NOT example_admin.can_do (
        a_user => 'mallory',
        a_action => 'insert',
        a_object_type => 'user',
        a_id => NULL::integer,
        a_parent_object_type => NULL::text,
        a_parent_id => NULL::integer ),
    'Unprivileged user cannot do' ) ;

SELECT ok (
    NOT example_admin.can_do (
        a_user => 'eve',
        a_action => 'insert',
        a_object_type => 'user',
        a_id => NULL::integer,
        a_parent_object_type => NULL::text,
        a_parent_id => NULL::integer ),
    'Under-privileged user cannot do' ) ;

SELECT ok (
    example_admin.can_do (
        a_user => 'trent',
        a_action => 'insert',
        a_object_type => 'user',
        a_id => NULL::integer,
        a_parent_object_type => NULL::text,
        a_parent_id => NULL::integer ),
    'Privileged user can do (insert)' ) ;

SELECT ok (
    example_admin.can_do (
        a_user => 'trent',
        a_action => 'update',
        a_object_type => 'user',
        a_id => (
            SELECT min ( id )
                FROM example_data.dt_user ),
        a_parent_object_type => NULL::text,
        a_parent_id => NULL::integer ),
    'Privileged user can do (update)' ) ;

\i 30_post_tap.sql
```

`cat test/tests/example_admin/02_test_user.sql`
```
\i 20_pre_tap.sql

SELECT plan ( 4 ) ;

SELECT ok (
    test.example_admin__insert_user (
        a_username => 'carol',
        a_first_name => 'Carol',
        a_last_name => 'Chad',
        a_email_address => 'Carol@example.com',
        a_app_roles => 'read',
        a_act_user => session_user::text,
        a_label => 'Insert user',
        a_should_pass => true
        ),
    'Insert user'
    ) ;

SELECT ok (
    test.example_admin__update_user (
        a_id => ( select id from example_data.dt_user where username = 'carol' ),
        a_username => 'carol',
        a_first_name => 'Carol',
        a_last_name => 'Smith',
        a_email_address => 'Carol@example.com',
        a_app_roles => 'read,write',
        a_act_user => session_user::text,
        a_label => 'Update user',
        a_should_pass => true
        ),
    'Update user'
    ) ;

SELECT ok (
    test.example_admin__upsert_user (
        a_id => ( select id from example_data.dt_user where username = 'carol' ),
        a_username => 'carol',
        a_first_name => 'Carol',
        a_last_name => 'Chad',
        a_email_address => 'Carol@example.com',
        a_app_roles => 'read',
        a_act_user => session_user::text,
        a_label => 'Upsert user',
        a_should_pass => true
        ),
    'Upsert user (update)'
    ) ;

SELECT ok (
    test.example_admin__upsert_user (
       a_username => 'dudley',
        a_first_name => 'Dudley',
        a_last_name => 'Doright',
        a_email_address => 'Dudley@example.com',
        a_app_roles => 'read',
        a_act_user => session_user::text,
        a_label => 'Upsert user',
        a_should_pass => true
        ),
    'Upsert user (insert)'
    ) ;

\i 30_post_tap.sql
```

### If using logging

If the util_log schema is in use then ensure that the manage_partitions
function is being periodically run or manually run it prior to testing:

```
psql -d example_db -c "select util_log.manage_partitions () ;"
```

### Run the tests

```
test/00_run_all.sh -d example_db -c
```

```
DELETE 0
DELETE 0
INSERT 0 6
DELETE 0
INSERT 0 7

#############################################################
#############################################################
# Testing tests/example_admin

#############################################################
# Running tests/example_admin/01_test_can_do.sql
SET
1..4
ok 1 - Unprivileged user cannot do
ok 2 - Under-privileged user cannot do
ok 3 - Privileged user can do (insert)
ok 4 - Privileged user can do (update)

#############################################################
# Running tests/example_admin/02_test_user.sql
SET
1..4
ok 1 - Insert user
ok 2 - Update user
ok 3 - Upsert user (update)
ok 4 - Upsert user (insert)

#############################################################
### Totals
Total Passed: 8 of 8

#############################################################
# Generating the plprofiler reports
## Creating test_profile.html
## Creating test_covered.html

SELECT 0
SELECT 0
Expanded display is on.
Pager usage is off.
```

### Test Coverage

Looking at the test coverage report generated using plprofiler
(`test/test_covered.html`) we can see that there is 57% test coverage of the
PL/pgSQL functions and procedures in the example_admin schema and 100% test
coverage of the PL/pgSQL functions and procedures in the priv_example_admin
schema. The details show that the example_admin.find_users,
example_admin.list_users, and example_admin.get_user function have no test
coverage.

Looking at the test profile report generated using plprofiler
(`test/test_profile.html`) we can see that logging (log_to_dblink) had the
highest total time measured which is not surprising considering the overall
simplicity of the application (so far). The next highest total time (not
counting the pgTAP and test functions) is the
priv_example_admin.priv_set_user_app_roles procedure, and the next highest
average time is the priv_example_admin.priv_insert_user procedure. Note that,
in the details section, clicking the show link for the functions/procedures
provides information on where in the function/procedure the time was spent.
