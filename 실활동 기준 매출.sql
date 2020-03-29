/*
먼저 결제를 하고 나중에 서비스가 제공되는 O2O 특성상, 의뢰별로 결제시점과 실제 서비스 제공 시점 사이의 시차가 발생한다.
이는 의뢰 등록이나 결제 시점이 아닌, 실제로 돌봄이 발생된 시점을 기준으로 매출의 발생추이를 추적하며
내부 환불 규정에 따라 사측에서 실제로 확보한 매출과 그렇지 않은(환불가능한) 매출을 구분하는 
*/


SELECT date_trunc, earned, sum(daily_sales)
FROM(
(SELECT
    DATE_TRUNC('month', generate_series)
    , 'earned' :: text AS earned
    , ROUND(SUM(earned_price_per_days)) :: integer AS daily_sales
FROM
    (SELECT
        *
    FROM
        (SELECT
            app.id AS app_id
            , sug.id AS sug_id
            , sug.task_id
            , sug.petner_id
            , sug.price
            , sug.body
            , app.start
            , app.end
        FROM suggestions AS sug
        JOIN appointments AS app
            ON sug.task_id = app.task_id
        WHERE sug.status = 1) AS task_app
            , GENERATE_SERIES(DATE_TRUNC('day', task_app.start), DATE_TRUNC('day',task_app.end),interval '1 day')) AS app_series
JOIN
    (SELECT
        sug.task_id
        , CASE WHEN EXTRACT(DAY FROM MIN(app.start) - NOW())+1 >= 5 then (SUM(sug.price)/COUNT(sug.task_id))/SUM(EXTRACT(day from app.end - app.start)+1 :: integer) * 0
			WHEN EXTRACT(DAY FROM MIN(app.start) - NOW())+1 < 5 AND EXTRACT(DAY FROM MIN(app.start) - NOW())+1 >=3 then (SUM(sug.price)/COUNT(sug.task_id))/SUM(EXTRACT(day from app.end - app.start)+1 :: integer) * 0.4
			WHEN EXTRACT(DAY FROM MIN(app.start) - NOW())+1 < 3 AND EXTRACT(DAY FROM MIN(app.start) - NOW())+1 >=2 then (SUM(sug.price)/COUNT(sug.task_id))/SUM(EXTRACT(day from app.end - app.start)+1 :: integer) * 0.5
			WHEN EXTRACT(DAY FROM MIN(app.start) - NOW())+1 < 2 AND EXTRACT(DAY FROM MIN(app.start) - NOW())+1 >=1 then (SUM(sug.price)/COUNT(sug.task_id))/SUM(EXTRACT(day from app.end - app.start)+1 :: integer) * 0.8
			ELSE (SUM(sug.price)/COUNT(sug.task_id))/SUM(EXTRACT(day from app.end - app.start)+1 :: integer) * 1 END as earned_price_per_days
    FROM suggestions AS sug
    JOIN appointments AS app
        ON sug.task_id = app.task_id
    WHERE sug.status = 1
    GROUP BY sug.task_id) AS day_price
    ON app_series.task_id = day_price.task_id
GROUP BY DATE_TRUNC('month', generate_series)
ORDER BY DATE_TRUNC('month', generate_series))

UNION ALL

(SELECT
    DATE_TRUNC('month', generate_series)
    , 'plus_unearned' :: text AS plus_unearned
    , ROUND(SUM(earned_price_per_days)) :: integer AS daily_sales
FROM
    (SELECT
        *
    FROM
        (SELECT
            app.id AS app_id
            , sug.id AS sug_id
            , sug.task_id
            , sug.petner_id
            , sug.price
            , sug.body
            , app.start
            , app.end
        FROM
            suggestions AS sug
        JOIN appointments AS app
            ON sug.task_id = app.task_id
        WHERE sug.status = 1) AS task_app
            , GENERATE_SERIES(DATE_TRUNC('day', task_app.start), DATE_TRUNC('day',task_app.end),interval '1 day')) AS app_series
JOIN
    (SELECT
	 	sug.task_id
        , SUM(sug.price)/COUNT(sug.task_id)/SUM(EXTRACT(day from app.end - app.start)+1 :: integer) as earned_price_per_days
    FROM suggestions AS sug
    JOIN appointments AS app
        ON sug.task_id = app.task_id
    WHERE sug.status = 1
    GROUP BY sug.task_id) AS day_price
    ON app_series.task_id = day_price.task_id
GROUP BY DATE_TRUNC('month', generate_series)
ORDER BY DATE_TRUNC('month', generate_series))) as earning_table

GROUP BY date_trunc, earned
ORDER BY date_trunc, earned
