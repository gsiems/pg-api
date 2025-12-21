| [Home](../readme.md) | [API](readme.md) | example_admin |

## Index<a name="top"></a>

 * Function [can_do](#function-can_do) returns boolean
 * Function [find_users](#function-find_users) returns SETOF priv_example_admin.dv_user
 * Function [get_user](#function-get_user) returns SETOF priv_example_admin.dv_user
 * Function [list_users](#function-list_users) returns SETOF priv_example_admin.dv_user
 * Procedure [delete_user](#procedure-delete_user)
 * Procedure [insert_user](#procedure-insert_user)
 * Procedure [update_user](#procedure-update_user)
 * Procedure [upsert_user](#procedure-upsert_user)

[top](#top)
## Function [can_do](../../schema/example_admin/function/can_do.sql)
Returns boolean

Function can_do determines if a user has permission to perform the specified action on the specified object (optionally for the specified ID)

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_user                         | in     | text       | The user to check permissions for                  |
| a_action                       | in     | text       | The action to perform                              |
| a_object_type                  | in     | text       | The (name of) the type of object to perform the action on |
| a_id                           | in     | integer    | The ID of the object to check permissions for      |
| a_parent_object_type           | in     | text       | The (name of) the type of object that is the parent of the object to check permissions for (this is for inserts) |
| a_parent_id                    | in     | integer    | The ID of the parent object to check permissions for (this is for inserts) |

NOTES

 * To help prevent privilege escalation attacks, both the acting user and the connected user need to have sufficient permissions to perform the action


[top](#top)
## Function [find_users](../../schema/example_admin/function/find_users.sql)
Returns SETOF priv_example_admin.dv_user

Function find_users Returns the list of matching user entries

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_act_user                     | in     | text       | The ID or username of the user doing the search    |
| a_search_term                  | in     | text       | The string to search for                           |


[top](#top)
## Function [get_user](../../schema/example_admin/function/get_user.sql)
Returns SETOF priv_example_admin.dv_user

Function get_user Returns the specified user entry

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id                           | in     | integer    | The system generated ID (primary key) for a user.  |
| a_username                     | in     | text       | The login username.                                |
| a_act_user                     | in     | text       | The ID or username of the user doing the search    |


[top](#top)
## Function [list_users](../../schema/example_admin/function/list_users.sql)
Returns SETOF priv_example_admin.dv_user

Function list_users

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_act_user                     | in     | text       | The ID or username of the user requesting the list |


[top](#top)
## Procedure delete_user

No source file found

[top](#top)
## Procedure [insert_user](../../schema/example_admin/procedure/insert_user.sql)

Procedure insert_user performs insert actions on example_data.dt_user

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id                           | inout  | integer    | The system generated ID (primary key) for a user.  |
| a_username                     | in     | text       | The login username.                                |
| a_first_name                   | in     | text       | The first name for the user.                       |
| a_last_name                    | in     | text       | The last name for the user.                        |
| a_email_address                | in     | text       | The email address for the user.                    |
| a_app_roles                    | in     | text       | The csv list of the role names for the user        |
| a_is_active                    | in     | boolean    | Indicates if the user account is active.           |
| a_act_user                     | in     | text       | The ID or username of the user performing the insert |
| a_err                          | inout  | text       | The (business or database) error that was generated, if any |


[top](#top)
## Procedure [update_user](../../schema/example_admin/procedure/update_user.sql)

Procedure update_user performs update actions on example_data.dt_user

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id                           | in     | integer    | The system generated ID (primary key) for a user.  |
| a_username                     | in     | text       | The login username.                                |
| a_first_name                   | in     | text       | The first name for the user.                       |
| a_last_name                    | in     | text       | The last name for the user.                        |
| a_email_address                | in     | text       | The email address for the user.                    |
| a_app_roles                    | in     | text       | The csv list of the role names for the user        |
| a_is_active                    | in     | boolean    | Indicates if the user account is active.           |
| a_act_user                     | in     | text       | The ID or username of the user performing the update |
| a_err                          | inout  | text       | The (business or database) error that was generated, if any |


[top](#top)
## Procedure [upsert_user](../../schema/example_admin/procedure/upsert_user.sql)

Procedure upsert_user performs upsert actions on example_data.dt_user

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id                           | inout  | integer    | The system generated ID (primary key) for a user.  |
| a_username                     | in     | text       | The login username.                                |
| a_first_name                   | in     | text       | The first name for the user.                       |
| a_last_name                    | in     | text       | The last name for the user.                        |
| a_email_address                | in     | text       | The email address for the user.                    |
| a_app_roles                    | in     | text       | The csv list of the role names for the user        |
| a_is_active                    | in     | boolean    | Indicates if the user account is active.           |
| a_act_user                     | in     | text       | The ID or username of the user performing the upsert |
| a_err                          | inout  | text       | The (business or database) error that was generated, if any |

