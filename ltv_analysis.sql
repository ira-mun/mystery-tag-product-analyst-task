-- get all install events with install date per user
WITH installs AS (
    SELECT user_id, created_at AS install_date
    FROM events
    WHERE event_name = 'install'
),
-- join events and installs table to get events per each day (1-14)
events_by_day AS (
    SELECT 
        e.user_id,
        e.event_name,
        e.revenue,
        i.install_date,
        DATE_PART('day', e.created_at - i.install_date) + 1 AS day_number
    FROM events e
    JOIN installs i ON e.user_id = i.user_id
    WHERE e.created_at >= i.install_date
      AND DATE_PART('day', e.created_at - i.install_date) <= 13
),
-- static day range to make sure that all days are included in the output
days AS (
  SELECT generate_series(1, 14) AS day_number
),
-- count the total number of unique installs
install_count AS (
  	SELECT COUNT(DISTINCT user_id) AS total_installs
  	FROM installs
),
-- calculate the first day of payment per user
payment_per_user AS(
	SELECT user_id, MIN(day_number) AS first_payment_day
	FROM events_by_day
	WHERE event_name = 'payment'
	GROUP BY user_id
),
-- count the number of users that made their first payment on each day
payers_by_day AS(
	SELECT first_payment_day, COUNT(user_id) AS payers
	FROM payment_per_user
	GROUP BY first_payment_day
),
-- cumulative payers across days
cumulative_payers_by_day AS(
	SELECT first_payment_day, SUM(payers) OVER(ORDER BY first_payment_day) AS cumulative_payers
	FROM payers_by_day
),
-- calculate the revenue on each day
revenue_by_day AS(
	SELECT day_number, SUM(revenue) as rev
	FROM events_by_day
	WHERE event_name = 'payment'
	GROUP BY day_number
),
-- cumulative revenue across days
cumulative_revenue_by_day AS(
	SELECT day_number, ROUND((SUM(rev) OVER(ORDER BY day_number))::numeric,2) AS cumulative_revenue
	FROM revenue_by_day
),
-- calculate unique users with sessions per day
sessions_by_day AS(
	SELECT day_number, COUNT(DISTINCT user_id) as session_users
	FROM events_by_day
	WHERE event_name = 'session'
	GROUP BY day_number
),
-- calculate percentage of paying, active users and ltv per day
percent_metrics AS(
	SELECT d.day_number,
			ROUND(cp.cumulative_payers/i.total_installs*100,2) || '%' AS payers_p,
			ROUND(s.session_users::numeric/i.total_installs*100,2) || '%' AS retention_p,
			ROUND(cr.cumulative_revenue::numeric/i.total_installs,3) AS ltv
	FROM days d
	CROSS JOIN install_count i
	LEFT JOIN cumulative_payers_by_day cp ON cp.first_payment_day = d.day_number
	LEFT JOIN cumulative_revenue_by_day cr ON cr.day_number = d.day_number
	LEFT JOIN sessions_by_day s ON s.day_number = d.day_number
)
-- final output
SELECT d.day_number AS "day", 
		i.total_installs AS "total installs", 
		cp.cumulative_payers AS "cumulative payers" ,
		cr.cumulative_revenue AS "cumulative revenue",
		s.session_users AS "session users",
		pm.payers_p AS "payers %",
		pm.retention_p AS "retention %",
		pm.ltv AS "LTV"
FROM days d
CROSS JOIN install_count i
LEFT JOIN cumulative_payers_by_day cp ON cp.first_payment_day = d.day_number
LEFT JOIN cumulative_revenue_by_day cr ON cr.day_number = d.day_number
LEFT JOIN sessions_by_day s ON s.day_number = d.day_number
LEFT JOIN percent_metrics pm ON pm.day_number = d.day_number