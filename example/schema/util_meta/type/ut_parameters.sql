CREATE TYPE util_meta.ut_parameters AS (
        names text[], -- The list of calling parameter names
        directions text[], -- The list of the parameter calling directions (in, out, inout)
        datatypes text[], -- The list of the parameter datatypes
        defaults text[], -- The list of the parameter defaults
        descriptions text[], -- The list of the parameter descriptions
        args text[] -- The list of named parameters to use when calling a function or procedure ("a_arg => a_arg")
    ) ;
