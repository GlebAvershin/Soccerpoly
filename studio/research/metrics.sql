SELECT scenario, MAX(target) AS target, MAX(safe_cash) AS safe_cash,
       CAST(ROUND(10000.0*SUM(CASE WHEN payout>=target THEN weight ELSE 0 END)/SUM(weight)) AS INT) AS probability_bp,
       MIN(payout) AS worst_shot, CAST(ROUND(100.0*SUM(payout*weight)/SUM(weight)) AS INT) AS expected_cash_hundredths
FROM samples GROUP BY scenario ORDER BY scenario
