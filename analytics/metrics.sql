-- Cohort membership is fixed by the first solo assignment. Every assigned player remains in the denominator.
CREATE VIEW assigned AS
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY ts, event_id) AS rank
    FROM events
    WHERE dataset = (SELECT cohort_dataset FROM analysis_config) AND name = 'OnboardingAssigned_v1' AND mode = 'solo'
)
SELECT player_id, session_id, ts AS assigned_at, variant, device, channel
FROM ranked WHERE rank = 1;

CREATE VIEW player_outcomes AS
SELECT a.*,
       MAX(CASE WHEN e.session_id = a.session_id AND e.name = 'FirstRouteSeconds_v2'
                       AND e.ts < a.assigned_at + 90 THEN 1 ELSE 0 END) AS route_90s,
       MAX(CASE WHEN e.session_id = a.session_id AND e.name = 'ClubSigned_v1'
                       AND e.ts < a.assigned_at + 420 THEN 1 ELSE 0 END) AS signed_7min,
       MAX(CASE WHEN e.session_id = a.session_id AND e.name = 'SeasonFinished_v1'
                       AND e.ts < a.assigned_at + 1200 THEN 1 ELSE 0 END) AS finished,
       MAX(CASE WHEN e.name = 'SeasonReplayed_v1' AND e.ts < a.assigned_at + 1200 THEN 1 ELSE 0 END) AS replayed,
       MAX(CASE WHEN e.name = 'SessionJoined' AND e.ts >= a.assigned_at + 86400
                       AND e.ts < a.assigned_at + 172800 THEN 1 ELSE 0 END) AS returned_d1
FROM assigned a
LEFT JOIN events e
    ON e.dataset = (SELECT cohort_dataset FROM analysis_config) AND a.player_id = e.player_id AND e.ts >= a.assigned_at
GROUP BY a.player_id, a.session_id, a.assigned_at, a.variant, a.device, a.channel;

CREATE VIEW segment_metrics AS
WITH tagged AS (
    SELECT 'all' AS dimension, 'all' AS segment, * FROM player_outcomes
    UNION ALL SELECT 'device', device, * FROM player_outcomes
    UNION ALL SELECT 'channel', channel, * FROM player_outcomes
)
SELECT dimension, segment, variant, COUNT(*) AS players, SUM(route_90s) AS routes,
       SUM(signed_7min) AS signing, SUM(finished) AS finishing, SUM(replayed) AS replaying,
       SUM(CASE WHEN assigned_at <= (SELECT MAX(ts) FROM events WHERE dataset = (SELECT cohort_dataset FROM analysis_config)) - 172800
                    THEN returned_d1 ELSE 0 END) AS d1_returned,
       SUM(CASE WHEN assigned_at <= (SELECT MAX(ts) FROM events WHERE dataset = (SELECT cohort_dataset FROM analysis_config)) - 172800
                    THEN 1 ELSE 0 END) AS d1_eligible
FROM tagged
GROUP BY dimension, segment, variant;

CREATE VIEW economy AS
SELECT CAST(mode AS INTEGER) AS seats,
       COUNT(DISTINCT session_id) AS tables,
       ROUND(AVG(CASE WHEN name = 'EndingCash' THEN value END), 2) AS avg_ending_cash,
       ROUND(AVG(CASE WHEN name = 'EndingValue' THEN value END), 2) AS avg_ending_value,
       ROUND(AVG(CASE WHEN name = 'OwnedClubs' THEN value END), 2) AS avg_clubs,
       ROUND(AVG(CASE WHEN name = 'StadiumUpgrades' THEN value END), 2) AS avg_upgrades,
       ROUND(AVG(CASE WHEN name = 'TableFees' THEN value END), 2) AS avg_fees,
       ROUND(AVG(CASE WHEN name = 'TableKickoffAwards' THEN value END), 2) AS avg_kickoff_credits,
       ROUND(1.0 * SUM(CASE WHEN name = 'TableGoals' THEN value ELSE 0 END)
                 / NULLIF(SUM(CASE WHEN name = 'TableCupVisits' THEN value ELSE 0 END), 0), 4) AS goals_per_cup_visit
FROM events WHERE dataset = 'rules_simulation'
GROUP BY mode;
