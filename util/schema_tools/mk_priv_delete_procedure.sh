#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

    mk_priv_delete_procedure.sh

DESCRIPTION

    Wrapper for the util_meta.mk_priv_delete_procedure DDL generation function

OPTIONS

    -d, --db database_name

        The name of the database to create scripts for

    -t, --dir schema_directory

        The base directory to create the DDL files in (defaults to ../../schema)

    -s, --object_schema schema_name

        The (name of the) schema that contains the table

    -n, --object_name object_name

        The (name of the) table to create the procedure for

    -D, --ddl_schema schema_name

        The (name of the) schema to create the procedure in (if different from the table schema)

    -o, --owner role_name

        The (optional) role that is to be the owner of the procedure

    -v, --verbose

        Verbosely list function executed and files written

    -h, --help

        Displays this help

EOT
    exit 0
}

cd "$(dirname "$0")" || exit 1

. maker_core.sh

cmd="SELECT util_meta.mk_priv_delete_procedure (
        a_object_schema => ${object_schema},
        a_object_name => ${object_name},
        a_ddl_schema => ${ddl_schema},
        a_owner => ${owner}
        ) ;"

generate_ddl_file procedure "${cmd}"
