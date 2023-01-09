SELECT *
FROM plans p JOIN subscriptions s
ON p.plan_id = s.plan_id
--										A. Data Analysis Questions
--1.How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id) total_customers
FROM subscriptions

--2.What is the monthly distribution of trial plan start_date values for our dataset 
SELECT COUNT(p.plan_id) AS trial_plan_count, DATEPART(MONTH FROM start_date) month
FROM plans p
JOIN subscriptions s
	ON p.plan_id = s.plan_id
WHERE p.plan_id = 0
GROUP BY DATEPART(MONTH FROM start_date) 
ORDER BY month

-- Average plans per month
WITH avg_trial_per_month AS (
SELECT COUNT(p.plan_id) AS trial_plan_count, DATEPART(MONTH FROM start_date) month
FROM plans p
JOIN subscriptions s
	ON p.plan_id = s.plan_id
WHERE p.plan_id = 0
GROUP BY DATEPART(MONTH FROM start_date) 
)
SELECT avg(trial_plan_count) avg_plans
FROM avg_trial_per_month

--3.What plan start_date values occur after the year 2020 for our dataset? 
--Show the breakdown by count of events for each plan_name
;WITH cte AS (
SELECT plan_name, s.plan_id, start_date
FROM subscriptions s
JOIN plans p
	ON s.plan_id = p.plan_id
WHERE start_date > '2020-12-31'
)
SELECT COUNT(plan_name) AS plan_count_2021, plan_name, plan_id
FROM cte
WHERE plan_id in (0, 1, 2, 3, 4, 5)
GROUP BY plan_name, plan_id
ORDER BY plan_id

--4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT COUNT(*) AS churn_count, CAST(100.0 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id) 
FROM subscriptions) AS float) AS churn_percent
FROM subscriptions
WHERE plan_id = 4

--5. How many customers have churned straight after their initial free trial.
--what percentage is this rounded to the nearest whole number?
WITH ranking AS (
SELECT customer_id, s.plan_id, plan_name,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY s.plan_id) AS rank
FROM subscriptions s
JOIN plans p
	ON s.plan_id = p.plan_id
)
SELECT COUNT(*) AS trial_to_churn,
ROUND(COUNT(*) * 100 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 0) percentage
FROM ranking
WHERE plan_id = 4 AND rank = 2

--6. What is the number and percentage of customer plans after their initial free trial?
WITH next_plan AS (
SELECT customer_id, plan_id,
LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id)  AS plan_after_trial
FROM subscriptions
)
SELECT plan_after_trial,
COUNT(*) AS conversions, CAST(100 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id)
FROM subscriptions) AS float) AS percentage
FROM next_plan
WHERE plan_after_trial IS NOT NULL
GROUP BY plan_after_trial
ORDER BY plan_after_trial 

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH plans_2020 AS (
SELECT customer_id, s.plan_id, plan_name, start_date,
LEAD(start_date, 1) OVER(PARTITION BY customer_id ORDER BY start_date) next_date
FROM subscriptions s JOIN plans p
ON s.plan_id = p.plan_id
WHERE start_date <= '2020-12-31'
),
plans_2021 AS (
SELECT plan_id, plan_name, COUNT(DISTINCT customer_id) AS customers_per_plan
FROM plans_2020
WHERE  next_date IS NOT NULL AND (start_date  < '2020-12-31' AND next_date > '2020-12-31') OR
	(next_date IS NULL AND start_date  < '2020-12-31')
GROUP BY plan_id, plan_name
)
SELECT plan_name, customers_per_plan, 
CAST(100.0 * customers_per_plan / (SELECT COUNT(DISTINCT customer_id) 
FROM subscriptions) AS float) AS percetange
FROM plans_2021
GROUP BY plan_id, plan_name, customers_per_plan
ORDER BY plan_id

--8. How many customers have upgraded to an annual plan in 2020?
SELECT COUNT(*) annual_plan_count
FROM subscriptions
WHERE plan_id = 3 AND start_date <= '2020-12-31'

--9. How many days on average does it take for a customer updgrade to an annual plan from the day they join Foodie-Fi?
WITH trial_plans AS (
SELECT customer_id, start_date AS trial_date
FROM subscriptions
WHERE plan_id = 0
),
annual_plans AS (
SELECT customer_id, start_date AS annual_date
FROM subscriptions
WHERE plan_id = 3
)
SELECT AVG(DATEDIFF(DAY, trial_date, annual_date)) AS avg_days_until_upgrade
FROM trial_plans t JOIN annual_plans a
ON t.customer_id = t.customer_id

--10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH  trial_plans AS (
SELECT customer_id, start_date AS trial_date
FROM subscriptions
WHERE plan_id = 0
),
annual_plan AS (
SELECT customer_id, start_date AS annual_date
FROM subscriptions
WHERE plan_id = 3
),
buckets AS (
SELECT tp.customer_id, trial_date, annual_date, 
DATEDIFF(DAY, trial_date, annual_date) / 30 + 1 AS bucket
FROM trial_plans tp JOIN annual_plan ap
ON tp.customer_id = ap.customer_id
)
SELECT 
CASE
	WHEN bucket = 1 THEN CONCAT(bucket - 1, '-', bucket * 30, ' days')
	ELSE CONCAT((bucket - 1) * 30 + 1, '-', bucket * 30, ' days')
END AS period,
COUNT(customer_id) AS total_customers
FROM buckets
GROUP BY bucket

--11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
;WITH next_plan_cte AS (
SELECT customer_id, plan_id, start_date, 
LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id) AS next_plan
FROM subscriptions
)
SELECT COUNT(*) AS downgraded
FROM next_plan_cte
WHERE start_date <= '2020-12-31' AND plan_id = 2 AND next_plan = 1
