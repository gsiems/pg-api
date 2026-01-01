#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

    mk_test_procedure_wrapper.sh

DESCRIPTION

    Wrapper for the util_meta.mk_test_procedure_wrapper test function generator

OPTIONS

    -d, --db database_name

        The name of the database to create procedure test wrappers for

    -t, --dir test_directory

        The base directory to create the test function files in (defaults to ../../test/)

    -T, --test_schema schema_name

        The (name of the) schema that the test wrapper functions will be created in

    -s, --object_schema schema_name

        The (name of the) schema that contains the procedure to create a test wrapper for

    -n, --object_name object_name

        The (name of the) procedure to create a test wrapper for

    -v, --verbose

        Verbosely list function executed and files written

    -h, --help

        Displays this help

EOT
    exit 0
}

cd "$(dirname "$0")" || exit 1

# Translate the long options
for arg in "$@"; do
    shift
    case "${arg}" in
        '--help') set -- "$@" '-h' ;;
        '--dir') set -- "$@" '-t' ;;
        '--verbose') set -- "$@" '-v' ;;
        '--db') set -- "$@" '-d' ;;
        '--object_name') set -- "$@" '-n' ;;
        '--object_schema') set -- "$@" '-s' ;;
        '--test_schema') set -- "$@" '-T' ;;
        *) set -- "$@" "$arg" ;;
    esac
done

# Set the default values
test_directory=../../test
test_schema="test"
unset object_name
unset object_schema
unset verbose

# Parse the (translated) short options
OPTIND=1
while getopts 'hvd:n:s:t:T:' arg; do
    case ${arg} in
        d) dbName="${OPTARG}" ;;
        n) object_name="'${OPTARG}'::text" ;;
        s) object_schema="'${OPTARG}'::text" ;;
        t) test_directory="${OPTARG}" ;;
        T) test_schema="'${OPTARG}'::text" ;;
        v) verbose=1 ;;
        *) usage=1 ;;
    esac
done

if [[ -n ${usage} ]]; then
    usage
fi

if [[ -z ${dbName} ]]; then
    echo "Please specify a name for the database"
    usage
fi

if [[ -z ${object_schema} ]]; then
    echo "Please specify the schema for the procedure being wrapped"
    usage
fi

if [[ -z ${object_name} ]]; then
    echo "Please specify a name of the procedure being wrapped"
    usage
fi

dsn=$(echo "${object_schema}" | cut -d ':' -f 1 | sed "s/'//g")
ddl_directory="${test_directory}"/tests/"${dsn}"/function

if [[ ! -d ${ddl_directory} ]]; then
    mkdir -p "${ddl_directory}"
fi

tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)

cmd="SELECT util_meta.mk_test_procedure_wrapper (
        a_object_schema => ${object_schema},
        a_object_name => ${object_name},
        a_test_schema => ${test_schema}
        ) ;"

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
