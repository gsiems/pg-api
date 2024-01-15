#!/usr/bin/sh

cd "$(dirname "$0")"

./01_reset_test_data.sh $@
./02_run_tests.sh $@
./03_run_plpgsql_check.sh $@
