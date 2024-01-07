-- hello world
SELECT a
  , b 
  , c
FROM public.table AS t
RIGHT JOIN helloworld.p
  ON cte.id = t.id
GROUP BY 1,2,3
HAVING a > 1;



-- WITH cte AS(
--   SELECT *
--   FROM
--     schema_a.runs AS b
--   INNER JOIN user_henry.logs AS n
--     ON n.id = b.id
--   WHERE b.id = 1
-- ),
--
-- cte2 AS (
--   SELECT *
--   FROM pg_activity.all
--   WHERE
--     b = "2"
-- )

SELECT a
  , b 
  , c
FROM public.tavle AS t
INNER JOIN asd.hello AS t ON t.id = t.id
WHERE
