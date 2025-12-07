# Naming Conventions and Considerations

## General

All database object names should be in lower snake-case with no special
characters that would require quoting the object name in order to reference it.
Ref: [4.1.1. Identifiers and Key Words](https://www.postgresql.org/docs/current/sql-syntax-lexical.html)

Names for database objects (tables, columns, views, etc.) should be clear and
should be consistently applied across all database objects. Avoid calling the
same concept by multiple different names.

Abbreviations, when used, should also be consistent across all database objects.

## Tables

User/application and reference data tables should be named with a prefix
indicating the type of table.

| Prefix    | Table Type                                    |
| --------- | --------------------------------------------- |
| dt_       | A user/application data table.                |
| ht_       | A historical data table. If used then the name should match the table that it stores the history for (e.g. dt_some_table_name -> ht_some_table_name ). |
| qt_       | A work queue table.                           |
| rt_       | A reference data table. These are tables that the business can typically be update without breaking the application.|
| st_       | A system reference or configuration table. These are tables that cannot be updated without causing application breakage or that contain system configuration (non-business) data. |

Other table types should not use the above prefixes.

While it may sometimes be unclear which prefix best fits a particular table the
idea is to give the users/developers a hint as to the basic purpose of any
given table and to also help with generating the appropriate database objects
for the table.

## Views

View names should follow the same naming conventions as tables with the
exception that the second character should be the letter "v" instead of "t".

## Relationships and Constraints

* Primary keys should consist of the table name followed by the "_pk" suffix.

* Natural keys should consist of the table name followed by the "_nk" suffix.

* Foreign key relationships should consist of the table name followed by the
"_fknn" suffix where nn is a zero-padded 2-digit number (fk01, fk02, etc.).
