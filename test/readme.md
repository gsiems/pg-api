# Testing

At the database level:

* There should be testing for all API entry points.

* Critical functionality should probably have more tests than non-critical
functionality.

* "Complex" functionality should probably have more tests than simple
functionality.

## Tools

### pgTAP

Uses the Test Anything Protocol for testing PostgreSQL functions, procedures,
and queries.

Note that the included bash scripts do not use the pg_prove utility (had issues
with running pg_prove using the system perl at one point (Redhat) and did not
want to maintain a separate perl environment).

* https://pgtap.org/
* https://pgxn.org/dist/pgtap/
* https://testanything.org/

### plpgsql_check

Plpgsql_check is a linter for PostgreSQL functions and procedures. Features
include (from the projects github repo):

* checks fields of referenced database objects and types inside embedded SQL
* validates you are using the correct types for function parameters
* identifies unused variables and function arguments, unmodified OUT arguments
* partial detection of dead code (code after an RETURN command)
* detection of missing RETURN command in function (common after exception handlers, complex logic)
* tries to identify unwanted hidden casts, which can be a performance issue like unused indexes
* ability to collect relations and functions used by function
* ability to check EXECUTE statements against SQL injection vulnerability

This helps developers catch/fix many potential bugs before publishing code
changes.

* https://github.com/okbob/plpgsql_check
* https://pgxn.org/dist/plpgsql_check/

### plprofiler

Plprofile can be used to measure performance characteristics of plpgsql
functions and procedures.

* https://github.com/bigsql/plprofiler

Having had issues with the client that comes with plprofiler on Redhat (missing
file(s) from the system python that prevented the client from working
correctly) and not being satisfied with the generated reports, a separate
client was created and/is used which generates both a performance profile
report and also a test coverage report. These reports do suffer the same
limitation as plprofiler itself in that they only work for plpgsql functions
and procedures vs. other function/procedure languages (sql, plperl, plpython,
etc.).

* https://github.com/gsiems/plprofiler_client

### Complexity

One tool that looks promising for calculating cyclomatic complexity is
https://github.com/sorenbronsted/sqlcc.

An approximate relative complexity can also be generated using something like
the following (this asserts that the SQL is formatted with upper case keywords):

```
kwl="IF
ELSE
ELSIF
WHEN
AND
OR
IN
ANY
BETWEEN
SELECT
INSERT
UPDATE
DELETE
UPSERT
MERGE
JOIN
WHERE
UNION
EXCEPT
INTERSECT
LIMIT
OFFSET
HAVING
PARTITION BY
GROUP BY
ORDER BY"

kwo=$(echo -n "${kwl}" | tr "\n" "|")
grep -cP "\s($kwo)\s" ../schema/*/*.sql | awk -F ':' '{print $2 " " $1}' | sort -nr | grep -P "^[0-9]{2}"
```

## Directories

* `plprofiler_client` Contains the files from
https://github.com/gsiems/plprofiler_client. Used by `02_run_tests.sh` for
running plprofiler and generating profiler and test coverage reports.

* `test_data` Contains files for resetting the database to a known initial
state.

* `tests` Contains pgTAP test files where each set of test files is contained
in a separate sub-directory.

## Files

* `00_run_all.sh` Runs everything.

* `01_reset_test_data.sh` Used for resetting the database to a known initial
state by running all sql files in the test_data directory. Files are run in
alpha-numeric order.

* `02_run_tests.sh` Run one or more test sets contained in the test directory.
Runs files in alpha-numeric order.

* `03_run_plpgsql_check.sh` Runs the plpgsql_check extension.

* `09_test_one.sh` Used for running individual tests. Useful for testing
specific functionality/bugs.

* `09_test_one.sql` Used in conjunction with `09_test_one.sh`

* `10_init_testrun.sql` Called by `02_run_tests.sh` to initialize the test
schema and ensure that the pgTAP extension is loaded.

* `20_pre_tap.sql` Called at the beginning of each pgTAP test file.

* `30_post_tap.sql` Called at the end of each pgTAP test file.

* `40_finalize_testrun.sql` Called by `02_run_tests.sh` at the end of the test
run to perform any needed cleanup.
