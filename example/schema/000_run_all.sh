#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

psql -f 000_run_all.sql postgres
