# Utilities

## `compare` Directory

* `do_ddl_compare.conf` contains configuration information for
`do_ddl_compare.sh`

* `do_ddl_compare.sh` uses the ddlx extension to export the DDL from 2 to 4
databases and compares the result using configuration information stored in
`do_ddl_compare.conf`

* `export_db_ddl.sh` exports the DDL for the specified database using the
ddlx extension.

* `grep_needed_grants.sh` greps the sql files in the schema directory and
attempts to determine the list of grants needed by the various schema owners in
order for the objects that they own to function properly.

## `doc` Directory

* `extract_api_doc.sh` generates API documentation by extracting comment blocks
from object DDL files (as markdoown files).

## `schema_tools` Directory

* `init_database_scripts.sh` Creates the initial scripts for creating a
database.

* `init_schema_scripts.sh` Creates both the directory structure for one or more
new schemas and the initial scripts for creating the schemas and schema
objects.

* `reconcile_source_files.sh` Reconciles the current list of DDL files in the
schema directories with the includes '\i' file list contained in the
create-[schema_name].sql files.

Included files that no longer exist should get commented out and new files
should get appended to the end of the appropriate create-[schema_name].sql
file.
