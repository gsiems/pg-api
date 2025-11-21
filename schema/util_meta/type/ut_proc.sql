CREATE TYPE util_meta.ut_proc AS (
        schema text, -- The name of the schema for the procedural unit
        name text, -- The name of the procedural unit
        full_name text, -- The full name of the procedural unit
        type text, -- The type of procedural unit (function, procedure)
        action text, -- The action that the procedural unit intends to perform
        --primary_table util_meta.ut_table, -- The (primary) table that the procedural unit operates on
        is_private boolean, -- Indicates if the procedural unit is private in scope
        description text -- The description/purpose of the procedural unit
    ) ;
