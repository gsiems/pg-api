#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

01_reset_test_data.sh

SYNOPSIS

    01_reset_test_data.sh [-d] [-p] [-u] [-q] [-h]

DESCRIPTION

    Truncates and re-loads test data using psql (*.sql) files in the test_data directory.

    Files are run in alpha-umeric order based on the filename.

OPTIONS

    -d database_name

        The name of the database to connect to (defaults to $USER)

    -p port

        The port to connect as (defaults to $PGPORT then 5432)

    -u user

        The name of the user to connect as (defaults to $USER)

    -q

        Quieter. Only print out errors.

    -h

        Displays this help

EOT
    exit 0
}

cd "$(dirname "$0")"

source ./set_env.sh

if [ ! -z "${usage}" ]; then
    usage
fi

function run_quietly() {

    for file in $(ls test_data/*.sql); do

        cmd="SET client_min_messages = warning ;
\i ${file}
"
        echo ${cmd} | psql -U ${usr} -d ${db} -p ${port} -f - >/dev/null

    done
}

function run_normal() {

    for file in $(ls test_data/*.sql); do
        psql -U ${usr} -d ${db} -p ${port} -f ${file}
    done
}

if [ -z "${quieter}" ] || [ "${quieter}" == "0" ]; then
    run_quietly
else
    run_normal
fi
