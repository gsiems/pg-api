#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

    mk_view.sh

DESCRIPTION

    Wrapper for the util_meta.mk_view DDL generation function

OPTIONS

    -d, --db database_name

        The name of the database to create scripts for

    -t, --dir schema_directory

        The base directory to create the DDL files in (defaults to ../../schema)

    -s, --object_schema schema_name

        The (name of the) schema that contains the table

    -n, --object_name object_name

        The (name of the) table to create the view for

    -D, --ddl_schema schema_name

        The (name of the) schema to create the view in (if different from the table schema)

    -b, --cast_booleans_as true_value,false_value

        The (optional) csv pair (true,false) of values to cast booleans as (if booleans are going to be cast to non-boolean values)

    -o, --owner role_name

        The (optional) role that is to be the owner of the view

    -g, --grantees role_name[,role_name[,role_name...]]

        The (optional) csv list of roles that should be granted select on the view

    -v, --verbose

        Verbosely list function executed and files written

    -h, --help

        Displays this help

EOT
    exit 0
}

cd "$(dirname "$0")" || exit 1

. maker_core.sh

cmd="SELECT util_meta.mk_view (
        a_object_schema => ${object_schema},
        a_object_name => ${object_name},
        a_ddl_schema => ${ddl_schema},
        a_cast_booleans_as => ${cast_booleans_as},
        a_owner => ${owner},
        a_grantees => ${grantees}
        ) ;"

generate_ddl_file view "${cmd}"
