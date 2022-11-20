# pg-api

Some assembly required

An exploration of combining a defined set of conventions with database
meta-data to assist in the creation (and testing!) of database level API
objects.

## Goals

1. To be able to create an actual API at the database level for use in interacting
with the database.

2. To minimize the amount of rote typing required for creating database objects.

3. To lean into the "Principle of Least Surprise" (PLS) (a.k.a. the
["Principle of Least Astonishment"](https://en.wikipedia.org/wiki/Principle_of_least_astonishment) (POLA)).

4. To encourage more up-front thought being put into the data model.

## Assertions

1. The database will have multiple different users connecting to it, either
directly or via a web application.

2. There will probably be some form of permissions model determining which
actions users may perform and/or the data that the users can see.

3. There is a strong likelihood that the database will have multiple different
clients connecting to it such as web applications, BI/reporting tools, batch
processes, etc.

4. There is a strong likelihood that there will be multiple developers working
on different portions of the data model and/or groups of database objects at
the same time.

## Project conventions

With a slight rewording of [rfc2119](https://www.rfc-editor.org/rfc/rfc2119),
the following keywords apply to project conventions:

1. *MUST* This word, or the terms *REQUIRED* or *SHALL*, mean that the
convention is an absolute requirement of the project.

2. *MUST NOT*  This phrase, or the phrase *SHALL NOT*, mean that the convention
is an absolute prohibition of the project.

3. *SHOULD* This word, or the adjective *RECOMMENDED*, mean that there may
exist valid reasons in particular circumstances to ignore a particular item,
but the full implications must be understood and carefully weighed before
choosing a different course.

4. *SHOULD NOT* This phrase, or the phrase *NOT RECOMMENDED* mean that there
may exist valid reasons in particular circumstances when the particular
behavior is acceptable or even useful, but the full implications should be
understood and the case carefully weighed before implementing any behavior
described with this label.

5. *MAY* This word, or the adjective *OPTIONAL*, mean that an item is truly
optional. Any implementation code which does not include a particular option
MUST be prepared to interoperate with another implementation which does include
the option, though perhaps with reduced functionality. In the same vein an
implementation which does include a particular option MUST be prepared to
interoperate with another implementation which does not include the option
(except, of course, for the feature the option provides.)

The key words *MUST*, *MUST NOT*, *REQUIRED*, *SHALL*, *SHALL NOT*, *SHOULD*,
*SHOULD NOT*, *RECOMMENDED*, *NOT RECOMMENDED*, *MAY*, and *OPTIONAL* in this
document are to be interpreted as described above when, and only when, they
appear in all capitals.

### Version control

This should go without saying, but there SHOULD be some form of Source Control
Management System (SCM) used for the project directory.

### File organization

* The "schema" directory

    * The root directory of the project SHALL contain a directory named "schema".

    * Within the "schema" directory there SHALL be a sub-directory for each
    actual database schema that is part of the project.

    * Within each schema sub-directory there SHALL be a sub-directory for each
    different type of database object:

        * table,
        * view,
        * materialized_view,
        * sequence,
        * type,
        * function,
        * procedure,
        * etc.

    * Each separate database object SHALL have a file containing the DDL for
    creating the object. The filename SHALL consist of the object name plus the
    ".sql" extension.

        * For example, the DDL for creating the "dt_user" table in the
        "my_data" schema would be located in the
        "schema/my_data/table/dt_user.sql" file.

    * For reference table objects, the object file SHOULD also contain the
    statements for inserting/copying the initial reference data.

    * Within the "schema" directory there SHALL be a file named
    nn_create-"schema_name".sql for each database schema that is part of the
    project (where nn refers to a numeric prefix such that listings of the
    files should be in the order they are to be run in).

        * This file SHALL be written for use by psql and SHALL have the
        necessary commands to create the database schema.

        * This file SHALL also have an "\i" directive for each DDL file for all
        objects that are to be created in the database schema. These directives
        SHALL be ordered such that the schema and all objects in the schema can
        be created without error by simply running the create schema file in
        psql.

    * Within the "schema" directory there SHOULD be psql compatible files for
    creating the database and any necessary roles, extensions, etc. needed for
    the database.

    * It SHOULD be possible to create and populate an instance of the database
    using just the "create" sql files in the root of the "schema" directory.
    The purpose of this goal is to enable multiple developers to have their own
    database instance to work with while enabling everyone to easily keep their
    instances in sync. Additionally, having the ability to script the database
    creation from scratch enables use of automated regression testing, CI/CD,
    etc.

* The "test" directory

    * Database level testing of procedures and functions SHOULD be performed.

    * It SHOULD be possible to automate the performance of the database level
    testing.

    * The RECOMMENDED extension to use for testing is [pgTap](https://pgtap.org/)

    * If database level testing is to be performed then:

        * The root directory of the project SHALL contain a directory for
        containing all the files and object definitions necessary to conduct the
        testing.

        * The directory name SHOULD be "test". If the project directory
        contains non-database elements such as middle-ware or application source
        code then the directory name SHOULD either indicate that the tests are
        for database level testing OR there should be a suitably named
        sub-directory under the "test" directory for containing the database
        level testing files.

        * It is RECOMMENDED that a "test" schema be created at the beginning of
        a test and that the developer defined database functions/procedures
        needed for running the test(s) are all created in that schema.

        * It is RECOMMENDED that the "test" schema be dropped at the conclusion
        of the test.

        * It is RECOMMENDED that the all the scripts necessary for running the
        test(s) exist under the "test" directory.

        * It is RECOMMENDED that the test scripts are structured such that a
        test can be run and then immediately re-run without (any additional)
        errors being generated.

### Schemas

The schema(s) that contain the tables/sequences SHOULD NOT also contain the
views, functions, and procedures used for interacting with the data. The goal
here is to make it easy to completely regenerate the API objects without
interfering with the table structures or table contents.

For large enough data-models where tables/relationships cluster into different
groupings then the API objects for those groupings SHOULD be organized into
different schemas with a separate schema for each grouping. The names of the
schemas SHOULD be based on the names of the groupings.

If a JSON API is to be created/maintained then the JSON emitting/ingesting
objects should exist in a separate schema from the regular API schema. It is
RECOMMENDED that the name of the json schema is a concatenation of the regular
API schema with a "_json" suffix.

### Database object naming

All database object names SHALL be lower snake-case with no special characters
that would require quoting the object name in order to reference it. Ref:
[4.1.1. Identifiers and Key Words](https://www.postgresql.org/docs/current/sql-syntax-lexical.html)

Object names SHOULD NOT start with "pg_". Schema names SHALL NOT start with
"pg_" as, to quote the
[documentation](https://www.postgresql.org/docs/current/sql-createschema.html)
for schema creation, "The name cannot begin with pg_, as such names are
reserved for system schemas."

Names for database objects (tables, columns, views, etc.) SHOULD be clear.
Names SHOULD also be consistently applied across all database objects. Avoid
calling the same concept by multiple different names.

Abbreviations, when used, SHOULD also be consistent across all database objects.

User/application and reference data tables SHALL be named with a prefix
indicating the type of table.

* The "dt_" prefix indicates a user/application data table.

* The "rt_" prefix indicates a reference data table. In general, these are
tables can be updated without risking application breakage.

* The "st_" prefix indicates a "system" reference table. In general, these are
tables that can NOT be updated without risking application breakage.

* The "ht_" prefix indicates a history table. If used then the name of the
history table SHOULD otherwise match the table that it is maintaining a history
of.

* Other types of tables such as temporary or work queue tables SHOULD NOT use
the "dt_", "rt_", "st_", or "ht_" prefixes.

While it may sometimes be unclear which prefix best fits a particular table the
idea is to give the users/developers a hint as to the basic purpose of any
given table and to also help with generating the appropriate database objects
for the table.

### Table primary keys

All tables SHALL have a primary key.

In general, each table SHOULD have a single column synthetic key. The
default column name is "id".

If there is a natural key for the table then there SHOULD be a unique
constraint on the columns that comprise the natural key. The name of this
constraint, if it exists, SHALL consist of the table name concatenated with an
"_nk" suffix. If there are multiple natural keys for a table then the "primary"
natural key SHALL be the one given the "_nk" suffix.

### Foreign keys

In general, it is preferred that the default name of a foreign key column is a
concatenation of the parent table name (minus the "dt_", "rt_", or "st_"
prefix) with the column name from the parent table as a suffix. For example, if
the dt_widget table references the rt_widget_type table and the column name of
the primary key of the rt_widget_type table is "id" then the default name for
the referencing column should be "widget_type_id" (that is, "rt_widget_type"
minus "rt_" plus "_id").

### Database access

The tables SHOULD NOT be directly accessed by users.

Queries SHOULD only be run against views or by set returning functions.

Inserts, updates, and deletes SHOULD only be accomplished through use of
database functions and/or procedures.

The goal here is to:

* Add a layer of abstraction between the tables such that it is easier to
refactor the table structure at a later date without promulgating too much
breakage to any clients using the database.

* Ensure that, if there are multiple client applications interacting with the
database, that the clients all play by the same rules. This is especially
important with respect to access control; if the access control is centralized
in the database itself then it is less likely that any client can subvert the
access rules.

#### API objects

For "regular" (non-JSON) interaction, updates to table data SHOULD be
accomplished by calling procedures (vs. functions).

For procedures, exceptions SHOULD be caught and returned from the procedure via
an inout text parameter (a_err). This is inspired by the Go language. The
thought here is that, if a single transaction consists of multiple procedure
calls, then the client should have the final say in whether, or how, the
transaction continues in the event of an error (retry the call, change the
inputs, rollback, etc.).

To the extent practicable, procedures and functions SHOULD be written to
avoid triggering exceptions. That is, do not rely on try/catch constructs.

#### JSON API objects

For updates where all the data necessary for the transaction is in the
submitted JSON then either functions or procedures MAY be used.

If functions are used then any parameters that would have been inout parameters
to a procedure SHOULD be in the result returned by the function.

The view(s)/user type(s) used for generating emitted JSON SHOULD be the same
ones used to unpack the ingested JSON.

The elements in JSON documents SHOULD be in camelCase:

* There appears to be no actual standard.

* snake_case is used by some tools/libraries.

* UpperCamelCase doesn't appear to be as common as camelCase or snake_case
(could be wrong about that).

* kebab-case appears to be straight-out.

* [json-api](https://jsonapi.org/) recommends (lower) camelCase and this
appears to be the most recommended approach overall.

* non-snake_case does result in more "mapping" of column names to and from the
desired casing, but this can mostly be auto-generated using table/view
meta-data.

## An aside

It is my stance that to develop a software system is to enter into a
relationship with the users and future maintainers of that system. As such,
what I like to call the "Cs of human healthy relationships" should be paid heed
to. I should note that these are not original thoughts on my part.

For human relationships these as:

* clean: no lies, be honest,

* clear: try to be clear in you communications; if you are unsure about
something then it is okay to ask for clarification; do not be angered if
clarification is requested,

* current: a.k.a. "Do not let the sun go down on your anger"; that is deal
with issues as they come up rather than stewing on them,

* conscious: be aware of the relationship, do not take it for granted or let
it run on auto-pilot, and

* compassionate: this should be a given and need no explanation.

In software, I think these could be translated as:

* clean: avoid/remove cruft from both the design, structure, and resulting
code as that can obscure/obfuscate the true state of things. Ensure that
documentation and database object and code comments accurately reflect the
thing being commented on,

* clear: structure, code, etc. should be as easy to understand and follow as
you can reasonably make it; the names of things should accurately reflect what
they are or what they do; strive to avoid ambiguity,

* current: acknowledge and either deal with issues as they come up or document
them for future reference,

* conscious: think about, and understand, what you are doing; avoid engaging in
["cargo-cult"] (https://en.wikipedia.org/wiki/Cargo_cult_programming)
development, management, etc., and

* compassionate: try to be considerate to those who will end up using and/or
maintaining your creation, or, if consideration isn't sufficient motivation,
then perhaps meditate on "Always code as if the person who ends up maintaining
your code is a violent psychopath who knows where you live."

## Quotes

* "Everything should be made as simple as possible, but no simpler." - Albert
Einstein

* "All models are wrong, but some are useful" - George E. P. Box

* "Bad programmers worry about the code. Good programmers worry about data
structures and their relationships." - Linus Torvalds

* "Show me your flowchart and conceal your tables, and I shall continue to be
mystified. Show me your tables, and I won't usually need your flowchart; it'll
be obvious." – Fred Brooks, The Mythical Man-Month.

* "Smart data structures and dumb code works a lot better than the other way
around." – Eric S. Raymond, The Cathedral and The Bazaar.

* "Rem tene, verba sequentur" ("Grasp the subject-matter, the words will
follow) - Cato the Elder
