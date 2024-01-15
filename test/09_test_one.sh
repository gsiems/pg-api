#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

09_test_one.sh

SYNOPSIS

    09_test_one.sh [-d] [-p] [-u] [-T] [-h]

DESCRIPTION

    Runs a single pgTap test as defined in the 09_test_one.sql file

OPTIONS

    -d database_name

        The name of the database to connect to (defaults to $PGDATABASE then $USER)

    -p port

        The port to connect as (defaults to $PGPORT then 5432)

    -u user

        The name of the user to connect as (defaults to $PGUSER then $USER)

    -T

        Truncate logs. Truncate the util_log.dt_proc_log table before
        running the test

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

if [ ${truncateLogs} -eq 1 ]; then
    psql -U ${usr} -d ${db} -p ${port} -c 'truncate table util_log.dt_proc_log ;'
fi

psql -U ${usr} -d ${db} -p ${port} -f 09_test_one.sql
