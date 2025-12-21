/**
## Role Passwords

[601_role_passwords](601_role_passwords.sql)

If it is necessary to hard-code some role passwords, ensure that they are not
hard-coded in any files that are version controlled as they then become visible
to anyone who has access to the code repository. Examples of this would include
credentials for foreign data wrappers to databases on different servers.

Instead, consider using files that are not version controlled to set the
passwords and set up some other mechanism for sharing them as needed.

*/

