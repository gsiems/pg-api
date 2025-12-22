#!/usr/bin/env bash

# Translate the long options
for arg in "$@"; do
    shift
    case "${arg}" in
        '--help') set -- "$@" '-h' ;;
        '--dir') set -- "$@" '-t' ;;
        '--verbose') set -- "$@" '-v' ;;
        '--db') set -- "$@" '-d' ;;
        '--action') set -- "$@" '-a' ;;
        '--cast_booleans_as') set -- "$@" '-b' ;;
        '--ddl_schema') set -- "$@" '-D' ;;
        '--grantees') set -- "$@" '-g' ;;
        '--is_row_based') set -- "$@" '-r' ;;
        '--object_name') set -- "$@" '-n' ;;
        '--object_schema') set -- "$@" '-s' ;;
        '--owner') set -- "$@" '-o' ;;
        '--parent_table_name') set -- "$@" '-N' ;;
        '--parent_table_schema') set -- "$@" '-S' ;;
        '--exclude_binary_data') set -- "$@" '-x' ;;
        '--insert_audit_columns') set -- "$@" '-i' ;;
        '--update_audit_columns') set -- "$@" '-u' ;;
        *) set -- "$@" "$arg" ;;
    esac
done

# Set the default values
action='null::text'
cast_booleans_as='null::text'
ddl_schema='null::text'
grantees='null::text'
is_row_based='null::boolean'
object_name='null::text'
object_schema='null::text'
owner='null::text'
parent_table_name='null::text'
parent_table_schema='null::text'
exclude_binary_data='null::boolean'
insert_audit_columns="'created_dt,created_by_id'::text"
update_audit_columns="'updated_dt,updated_by_id'::text"
schema_directory=../../schema
unset verbose

# Parse the (translated) short options
OPTIND=1
while getopts 'hrva:b:d:D:g:i:n:N:o:s:S:t:u:x:' arg; do
    case ${arg} in
        a) action="'${OPTARG}'::text" ;;
        b) cast_booleans_as="'${OPTARG}'::text" ;;
        d) dbName="${OPTARG}" ;;
        D) ddl_schema="'${OPTARG}'::text" ;;
        g) grantees="'${OPTARG}'::text" ;;
        i) insert_audit_columns="'${OPTARG}'::text" ;;
        n) object_name="'${OPTARG}'::text" ;;
        N) parent_table_name="'${OPTARG}'::text" ;;
        o) owner="'${OPTARG}'::text" ;;
        r) is_row_based='true' ;;
        s) object_schema="'${OPTARG}'::text" ;;
        S) parent_table_schema="'${OPTARG}'::text" ;;
        t) schema_directory="${OPTARG}" ;;
        u) update_audit_columns="'${OPTARG}'::text" ;;
        v) verbose=1 ;;
        x) exclude_binary_data='true' ;;
        *) usage=1 ;;
    esac
done

if [[ -n ${usage} ]]; then
    usage
fi

function generate_ddl_file() {
    local type="${1}"
    local cmd="${2}"

    if [[ -z ${dbName} ]]; then
        echo "Please specify a name for the database"
        usage
    fi

    dsn=$(echo "${ddl_schema}" | cut -d ':' -f 1 | sed "s/'//g")
    ddl_directory="${schema_directory}/${dsn}/${type}"

    if [[ ! -d ${ddl_directory} ]]; then
        mkdir -p "${ddl_directory}"
    fi

    tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    if [[ -n ${verbose} ]]; then
        echo ""
        echo "Writing:"
        echo "${cmd}"
    fi

    echo "${cmd}" | psql -q -t --csv example_db -f - >"${tmp_file}"

    obj_name="$(head -n 1 "${tmp_file}" | cut -d '(' -f 1 | awk '{print $NF}' | cut -d '.' -f 2)"
    out_file="${ddl_directory}/${obj_name}.sql"

    if [[ -n ${verbose} ]]; then
        echo "To ${out_file}"
    fi

    cat "${tmp_file}" | sed -e 's/^"//' -e 's/" *$//' >"${out_file}"
    rm "${tmp_file}"
}
