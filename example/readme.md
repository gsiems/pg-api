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
            a_object_schema => 'example_data',
            a_object_name => 'dt_user',
            a_ddl_schema => 'example_admin'
        ) ;
SELECT util_meta.mk_get_function (
            a_object_schema => 'example_data',
            a_object_name => 'dt_user',
            a_ddl_schema => 'example_admin'
        ) ;
SELECT util_meta.mk_list_function (
            a_object_schema => 'example_data',
            a_object_name => 'dt_user',
            a_ddl_schema => 'example_admin'
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
source generators.sh
ddl_schema=example_admin
table_schema=example_data

gen_api_proc_ddl "${ddl_schema}" "${table_schema}" dt_user insert
gen_api_proc_ddl "${ddl_schema}" "${table_schema}" dt_user update
gen_api_proc_ddl "${ddl_schema}" "${table_schema}" dt_user upsert
```

```
SELECT util_meta.mk_api_procedure (
            a_action => 'insert',
            a_object_schema => 'example_data',
            a_object_name => 'dt_user',
            a_ddl_schema => 'example_admin',
            a_insert_audit_columns => 'created_dt,created_by_id',
            a_update_audit_columns => 'updated_dt,updated_by_id'
        ) ;
SELECT util_meta.mk_api_procedure (
            a_action => 'update',
            a_object_schema => 'example_data',
            a_object_name => 'dt_user',
            a_ddl_schema => 'example_admin',
            a_insert_audit_columns => 'created_dt,created_by_id',
            a_update_audit_columns => 'updated_dt,updated_by_id'
        ) ;
SELECT util_meta.mk_api_procedure (
            a_action => 'upsert',
            a_object_schema => 'example_data',
            a_object_name => 'dt_user',
            a_ddl_schema => 'example_admin',
            a_insert_audit_columns => 'created_dt,created_by_id',
            a_update_audit_columns => 'updated_dt,updated_by_id'
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

## Setup testing

TODO
