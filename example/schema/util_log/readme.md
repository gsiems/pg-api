
# On autonomous transactions (for logging)

 * https://blog.dalibo.com/2016/08/19/Autonoumous_transactions_support_in_PostgreSQL.html
 * https://www.cybertec-postgresql.com/en/implementing-autonomous-transactions-in-postgres/
 * https://aws.amazon.com/blogs/database/migrating-oracle-autonomous-transactions-to-postgresql/


Timing the current pgTap test set for each logging method: none, dblink, and pg_background.

| logging type      | real      | user      | sys       |
| ----------------- | --------- | --------- | --------- |
| none              | 0m1.208s  | 0m0.067s  | 0m0.079s  |
| none              | 0m1.271s  | 0m0.071s  | 0m0.073s  |
| none              | 0m1.250s  | 0m0.067s  | 0m0.076s  |
| dblink            | 0m1.683s  | 0m0.070s  | 0m0.074s  |
| dblink            | 0m1.716s  | 0m0.080s  | 0m0.068s  |
| dblink            | 0m1.742s  | 0m0.070s  | 0m0.075s  |
| pg_background     | 0m1.467s  | 0m0.067s  | 0m0.075s  |
| pg_background     | 0m1.480s  | 0m0.070s  | 0m0.073s  |
| pg_background     | 0m1.525s  | 0m0.070s  | 0m0.071s  |

Taking the average of the three runs each

| logging type      | real      | user      | sys       |
| ----------------- | --------- | --------- | --------- |
| none              | 1.243s    | 0.068s    | 0.076s    |
| dblink            | 1.714s    | 0.073s    | 0.072s    |
| pg_background     | 1.491s    | 0.069s    | 0.073s    |

While not at all statistically valid (only three runs) this does indicate that, as expected. logging is not free.

Looking at the percent difference relative to no (disabled) logging:

| logging type      | real      | user      | sys       |
| ----------------- | --------- | --------- | --------- |
| dblink            | 137.87%   | 107.32%   | 95.18%    |
| pg_background     | 119.92%   | 100.98%   | 96.05%    |

It appears that dblink is slower than using pg_background although dblink does not appear to suffer from running out of background process.
