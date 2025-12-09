# Conventions

## Contents

* [Layout](#1.0-layout)
* [Database](#2.0-database)
* [Documentation](#3.0-documentation)

## 1.0 Layout

**1.0.1** The (database portion of) the project should be the same for all
projects.

**1.0.2** The minimal directory structure should look like:

```
./
 ├── readme.md
 ├── doc/
 ├── schema/
 ├── test/
 └── util/
```

 * `readme.md`: Description of the (database portion of the) project
 * [`doc`](readme.md): Documentation files
 * [`schema`](../schema/readme.md): Contains the files for creating the database schema(s) and their objects
 * [`test`](../test/readme.md): Contains the files used for performing database level testing
 * [`util`](../util/readme.md): Contains any utility scripts used for the database development

**1.0.3** Other directories should each contain a readme that describes the
purpose of the directory, and any guidance/rules as to the use of the contents
of the directory (the what, why, and how of the directory).

# 2.0 Database

### 2.1.0 Naming

**2.1.1** Quoting the PostgreSQL documentation: "SQL identifiers and key words
must begin with a letter (a-z, but also letters with diacritical marks and
non-Latin letters) or an underscore (_). Subsequent characters in an identifier
or key word can be letters, underscores, digits (0-9), or dollar signs ($).
Note that dollar signs are not allowed in identifiers according to the letter
of the SQL standard, so their use might render applications less portable."

Avoid using dollar signs ($) in identifiers.

Avoid using a leading underscore (_) in table and column identifiers.

Avoid using SQL key words for identifiers.

References:
 * [4.1.1. Identifiers and Key Words](https://www.postgresql.org/docs/current/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS)
 * [Appendix C. SQL Key Words](https://www.postgresql.org/docs/current/sql-keywords-appendix.html)

**2.1.2** Identifiers for database objects (tables, columns, views, etc.) should
be clear and should be consistently applied across all database objects. Avoid
calling the same concept by multiple different names. Also avoid calling
different concepts by the same name.

**2.1.3** Abbreviations (and acronyms), when used, should also be consistent
across all database objects.

**2.1.4** Abbreviations (and acronyms), when used, should be defined in a
[glossary of terms](glossary.md)

### 2.2.0 Ownership

**2.1.5** Database objects should be owned by a NOLOGIN role that is not granted
to any other roles.

### 2.2.0 Schemas

**2.2.1** Schemas are essentially free in PostgreSQL so use them to organize
groups of related concepts or functionalities.

**2.2.2** To the extent practicable, database objects that are considered to be
non-public (not available to LOGIN roles) should be kept in separate schemas
from public objects.

**2.2.3** Identifiers for non-public schemas should have a consistent prefix
indicating the non-public nature of the schema contents (`util_meta` recognizes
`priv_` and `_`).

**2.2.4** Schemas should have database comments (`COMMENT ON SCHEMA ... IS ...`).

### 2.3.0 Tables, Views, and Materialized Views

**2.3.1** Tables should not be directly accessible to LOGIN roles. All
interaction should be mediated through views, functions, and procedures. The
rational for this is that when LOGIN roles can directly access tables it makes
modifying/refactoring the data-model harder as it may be difficult to determine
what will get broken due to any changes made.

**2.3.2** Tables should use single column synthetic primary keys with the
data-type being some form of integer and having a preferred column name of
`id`. Using `id` as the column name makes it obvious which column is the
primary key on tables that have multiple `*_id` columns (also, `table_name.id`
*should* be fairly unambiguous).

**2.3.3** Identifiers for columns that have a foreign key constraint on a
different table should default to the table name (minus the prefix bit) plus
the column name of the referenced table (`id`) (i.e. for a table that has a FK
relationship to the `id` column of the `rt_widget_type` table default
identifier for the column should be `widget_type_id`).

**2.3.4** Data tables should be maintained in a separate schema, or schemas, from
everything else. Benefits include helping with managing database permissions,
and allowing developers to drop and re-create API schemas without risking
damage to tables or data.

**2.3.5** User/application and reference data tables should be named with a
prefix indicating the type of table/data stored in the table.

| Prefix    | Table Type                                    |
| --------- | --------------------------------------------- |
| dt_       | A user/application data table.                |
| ht_       | A historical data table. If used then the name should match the table that it stores the history for (e.g. dt_some_table_name -> ht_some_table_name ). |
| qt_       | A work queue table.                           |
| rt_       | A reference data table. These are tables that the business can typically be update without breaking the application.|
| st_       | A system reference or configuration table. These are tables that cannot be updated without causing application breakage or that contain system configuration (non-business) data. |
| tt_       | A temporary table.                            |

Other table types should have different prefixes not use the above prefixes.

While it may sometimes be unclear which prefix best fits a particular table the
idea is to give the users/developers a hint as to the basic purpose of any
given table and to also help with generating the appropriate database objects
for the table.

**2.3.6** Table names should be consistently singular or plural. My preference is
to use the singular so the users table would be named dt_user rather than
dt_users. NB that, while the `information_schema` schema uses plural table/view
identifiers, the `pg_catalog` schema uses singular.

**2.3.7** View names should follow the same naming conventions as tables with the
exception that the second character should be the letter `v` instead of `t`
(`dv_`, `rv_`, etc.).

**2.3.8** Materialized view names should follow the same naming conventions as
tables with the exception that the second character should be the letter `m`
instead of `t` (`dm_`, `rm_`, etc.).

**2.3.9** There will be a users table (`util_meta` expects there to be one).

**2.3.10** Identifiers for primary keys should consist of the table name followed
by a consistent suffix. The PostgreSQL default suffix is `_pkey` while I prefer
using `_pk` as the suffix.

**2.3.11** Natural keys should be enforced using unique constraints. Identifiers
for natural keys should follow a consistent naming convention and use a
consistent suffix. The PostgreSQL default identifier appears to be table_name,
column name(s) (separated by underscores) with a `_key` suffix (my preference
is to use the table name followed by the `_nk` suffix (and add a trailing
numeric for tables with multiple natural keys)). My issue with using column
names in the identifier are:
 * the identifiers can get needlessly long
 * if the resulting identifier would be too long then something will get
 truncated
 * renaming a column (`ALTER TABLE ... RENAME COLUMN ...`) doesn't rename the
 constraint and the identifier is no longer accurate

**2.3.12** Identifiers for foreign key relationships should should follow a
consistent naming convention and use a consistent suffix. The PostgreSQL
default identifier appears to be table_name, column name(s) (separated by
underscores) with a `_fkey` suffix (my preference is to use the table name
followed by the `_fknn` suffix where `nn` is a zero-padded 2-digit number
(`_fk01`, `_fk02`, etc.)).

**2.3.13** Tables and columns should have database comments (`COMMENT ON ... IS
...`).

### 2.4.0 Functions and Procedures.

**2.4.1** Functions should be used for selecting data that is restricted by the
permissions model for the application (as the function can incorporate a
permissions check).

**2.4.2** Procedures should be used for modifying data.

**2.4.3** Function and procedure identifiers should consist of an action - item
name pair that indicates the action being taken and the kind of thing the
action is being taken on (i.e. `insert_user`, `cancel_order`,
`calibrate_test_equipment`, etc.). Action and item pair names should be
consistent across all database objects.

**2.4.4** Functions and procedures that are non-public should be in a schema for
non-public objects and/or their identifiers should have a prefix indicating the
non-public nature of the function/procedure (`util_meta` recognizes `priv_` and
`_`).

### 2.5.0 Roles

**2.5.1** Database users/roles should have database comments stating the
purpose for the role and/or who uses the role (login roles).

## 3.0 Documentation

**3.0.1** All schemas, tables, views, and columns should have database
comments. These comments will be used when drafting dependent database objects
(views, functions, and procedures). Use a
[tool][https://github.com/gsiems/db-dictionary] to extract those comments to
build/maintain a data dictionary.

The documentation for database objects should be maintained in the source code
files for the database objects.

**3.0.2** Documentation for functions and procedures should be contained in
block comments where:

* the comment start is on a separate line and begins with two (or more) asterisks ('/**')
* the comment end is on a separate line ('*/')
* the comment content is formatted using markdown

```
    /**
    Comments to extract
    */

    /*
    Comments to ignore
    */
```

**3.0.3** Use a [utility](../util/doc/extract_api_doc.sh) to extract the API object
documentation into a single [location](api/readme.md) for use by users of
the API. Use the tool to update the API documentation whenever objects are
added, removed, or the object documentation is updated.
