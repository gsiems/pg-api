#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

    mk_find_function.sh

DESCRIPTION

    Wrapper for the util_meta.mk_find_function DDL generation function

OPTIONS

    -d, --db database_name

        The name of the database to create scripts for

    -t, --dir schema_directory

        The base directory to create the DDL files in (defaults to ../../schema)

    -s, --object_schema schema_name

        The (name of the) schema that contains the table

    -n, --object_name object_name

        The (name of the) table to create the function for

    -D, --ddl_schema schema_name

        The (name of the) schema to create the function in (if different from the table schema)

    -r, --is_row_based

        Indicates if the permissions model is row-based (default is table based)

    -o, --owner role_name

        The (optional) role that is to be the owner of the function

    -g, --grantees role_name[,role_name[,role_name...]]

        The (optional) csv list of roles that should be granted execute on the function

    -v, --verbose

        Verbosely list function executed and files written

    -h, --help

        Displays this help

EOT
    exit 0
}

cd "$(dirname "$0")" || exit 1

. maker_core.sh

cmd="SELECT util_meta.mk_find_function (
        a_object_schema => ${object_schema},
        a_object_name => ${object_name},
        a_ddl_schema => ${ddl_schema},
        a_is_row_based => ${is_row_based},
        a_owner => ${owner},
        a_grantees => ${grantees}
        ) ;"

generate_ddl_file function "${cmd}"
