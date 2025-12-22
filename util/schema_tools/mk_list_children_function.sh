#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

    mk_list_children_function.sh

DESCRIPTION

    Wrapper for the util_meta.mk_list_children_function DDL generation function

OPTIONS

    -d, --db database_name

        The name of the database to create scripts for

    -t, --dir schema_directory

        The base directory to create the DDL files in (defaults to ../../schema)

    -s, --object_schema schema_name

        The (name of the) schema that contains the table

    -n, --object_name object_name

        The (name of the) table to create the function for

    -S, --parent_table_schema schema_name

        The (name of the) schema that contains the parent table

    -N, --parent_table_name table_name

        The (name of the) parent table

    -D, --ddl_schema schema_name

        The (name of the) schema to create the function in (if different from the table schema)

    -x, --exclude_binary_data exclude_binary_data

        Indicates if binary (bytea, jsonb) data is to be excluded from the result-set (default is to include binary data)

    -i, --insert_audit_columns column_name[,column_name[,column_name...]]

        The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit

    -u, --update_audit_columns column_name[,column_name[,column_name...]]

        The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit

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

cmd="SELECT util_meta.mk_list_children_function (
        a_object_schema => ${object_schema},
        a_object_name => ${object_name},
        a_parent_table_schema => ${parent_table_schema},
        a_parent_table_name => ${parent_table_name},
        a_ddl_schema => ${ddl_schema},
        a_exclude_binary_data => ${exclude_binary_data},
        a_insert_audit_columns => ${insert_audit_columns},
        a_update_audit_columns => ${update_audit_columns},
        a_owner => ${owner},
        a_grantees => ${grantees}
        ) ;"

generate_ddl_file function "${cmd}"
