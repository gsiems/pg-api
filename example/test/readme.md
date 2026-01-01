#



grep -cP "\s(IF|ELSE|ELSIF|WHEN|AND|OR|IN|ANY|BETWEEN|SELECT|INSERT|UPDATE|DELETE|UPSERT|MERGE|JOIN|UNION|EXCEPT|GROUP BY|ORDER BY)\s"  schema/*example*/*/* | awk -F ':' '{print $2 " " $1}' | sort -nr | head -n 15




kw="IF
ELSE
ELSIF
WHEN
AND
OR
IN
ANY
BETWEEN
SELECT
INSERT
UPDATE
DELETE
UPSERT
MERGE
JOIN
WHERE
UNION
EXCEPT
INTERSECT
LIMIT
OFFSET
HAVING
PARTITION BY
GROUP BY
ORDER BY"

foo=$(echo -n "${kw}" | tr "\n" "|")
grep -cP "\s($foo)\s" schema/*example*/*/* | awk -F ':' '{print $2 " " $1}' | sort -nr | head -n 15
