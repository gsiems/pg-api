CREATE TYPE util_meta.ut_parameters AS (
    names      text[], -- The list of calling parameter names
    directions text[], -- The list of the calling parameter directions
    datatypes  text[], -- The list of the datatypes for the parameters
    comments   text[], -- The list of the comments for the parameters
    args       text[]  -- The list of named parameters to use when calling a function or procedure ("a_arg => a_arg")
    ) ;
