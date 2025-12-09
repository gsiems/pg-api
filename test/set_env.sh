#!/usr/bin/env bash

quieter=0
truncateLogs=0
coverage=0

banner="#############################################################"

########################################################################
# Read the calling args
while getopts 'chqTd:p:u:f:' arg; do
    case ${arg} in
        c) coverage=1 ;;
        d) db="${OPTARG}" ;;
        f) file="${OPTARG}" ;;
        h) usage=1 ;;
        p) port="${OPTARG}" ;;
        q) quieter=$((quieter + 1)) ;;
        T) truncateLogs=1 ;;
        u) usr="${OPTARG}" ;;
        *) usage=1 ;;
    esac
done

if [[ -z ${usr} ]]; then
    if [[ -n ${PGUSER} ]]; then
        usr="${PGUSER}"
    else
        usr="${USER}"
    fi
fi
if [[ -z ${db} ]]; then
    if [[ -n ${PGDATABASE} ]]; then
        db="${PGDATABASE}"
    else
        db="${USER}"
    fi
fi
if [[ -z ${port} ]]; then
    if [[ -n ${PGPORT} ]]; then
        port="${PGPORT}"
    else
        port=5432
    fi
fi
