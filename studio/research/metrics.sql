SELECT scenario, MAX(target) AS target, SUM(weight) AS total_weight,
       SUM(CASE WHEN safe_cash>=target THEN weight ELSE 0 END) AS guaranteed_success_weight,
       SUM(CASE WHEN payout>=target THEN weight ELSE 0 END) AS shot_success_weight
FROM samples GROUP BY scenario ORDER BY scenario
