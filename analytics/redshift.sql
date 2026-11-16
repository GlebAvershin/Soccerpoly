-- Replace the S3 URI with a same-Region PARQUET export before running with an approved IAM role.
-- Spark column order: mode, tables, cash, value, clubs, upgrades, fees, kickoff, goal ratio.
CREATE TABLE IF NOT EXISTS worlddraft_economy (
    mode VARCHAR(1) NOT NULL,
    tables BIGINT NOT NULL,
    avg_ending_cash DOUBLE PRECISION,
    avg_ending_value DOUBLE PRECISION,
    avg_clubs DOUBLE PRECISION,
    avg_upgrades DOUBLE PRECISION,
    avg_fees DOUBLE PRECISION,
    avg_kickoff_credits DOUBLE PRECISION,
    goals_per_cup_visit DOUBLE PRECISION
);

CREATE TEMP TABLE worlddraft_economy_stage (LIKE worlddraft_economy);
COPY worlddraft_economy_stage
FROM 's3://YOUR_BUCKET/worlddraft/economy/RUN_ID/'
IAM_ROLE default
FORMAT AS PARQUET;

-- Before publishing, compare these checks with the recorded lineage and decide whether to proceed.
SELECT COUNT(*) AS rows, COUNT(DISTINCT mode) AS distinct_table_sizes,
       SUM(CASE WHEN tables < 1 OR mode NOT IN ('2','3','4','5','6') THEN 1 ELSE 0 END) AS invalid
FROM worlddraft_economy_stage;

BEGIN;
DELETE FROM worlddraft_economy
USING worlddraft_economy_stage
WHERE worlddraft_economy.mode = worlddraft_economy_stage.mode;
INSERT INTO worlddraft_economy SELECT * FROM worlddraft_economy_stage;
COMMIT;
