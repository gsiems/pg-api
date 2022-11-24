CREATE OR REPLACE FUNCTION util_meta.is_valid_object (
    a_object_schema text,
    a_object_name text,
    a_object_type text )
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
/**
Function is_valid_object checks if the specified object exists in the database

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the object  |
| a_object_name                  | in     | text       | The (name of the) object to check the existence of |
| a_object_type                  | in     | text       | The (name of the) type of object to check the existence of |

*/

    SELECT EXISTS (
        SELECT 1
            FROM util_meta.objects
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
                AND object_type = a_object_type ) ;

$$ ;
