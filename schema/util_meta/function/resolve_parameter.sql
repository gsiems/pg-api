CREATE OR REPLACE FUNCTION util_meta.resolve_parameter (
    a_name text default null,
    a_value text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function resolve_parameter checks/resolves a calling parameter and returns the parameter value.

If the parameter value is specified then it is checked (as applicable) to determine if it is valid.

If the parameter value is not specified then the default for that parameter (as applicable) is returned.

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_name                         | in     | text       | The name of the parameter to resolve               |
| a_value                        | in     | text       | The supplied value of the parameter to resolve     |

*/
DECLARE

    r record  ;

BEGIN

    /*

    | a_value   | has allowed_values | is valid value | has config_value | has default_value | result        |
    | --------- | ------------------ | -------------- | ---------------- | ----------------- | ------------- |
    | null      | either             | n/a            | true             | true              | config_value  |
    | null      | either             | n/a            | true             | false             | config_value  |
    | null      | either             | n/a            | false            | true              | default_value |
    | null      | either             | n/a            | false            | false             | null          |
    | not null  | true               | true           | n/a              | n/a               | a_value       |
    | not null  | true               | false          | true             | true              | config_value  |
    | not null  | true               | false          | true             | false             | config_value  |
    | not null  | true               | false          | false            | true              | default_value |
    | not null  | false              | n/a            | either           | either            | a_value       |

    */

    FOR r IN (
        SELECT dp.allowed_values,
                coalesce ( cd.config_value, dp.default_value ) AS default_value
            FROM util_meta.st_default_param dp
            LEFT JOIN util_meta.rt_config_default cd
                ON ( cd.default_param_id = dp.id )
            WHERE dp.name = a_name ) LOOP

        IF a_value IS NULL THEN
            RETURN r.default_value ;
        ELSIF r.allowed_values IS NULL THEN
            RETURN coalesce ( a_value, r.default_value ) ;
        ELSIF a_value = ANY (string_to_array ( r.allowed_values, ',' ) ) THEN
            RETURN a_value ;
        ELSE
            RETURN r.default_value ;
        END IF ;

    END LOOP ;

    RETURN a_value ;

END ;
$$ ;
