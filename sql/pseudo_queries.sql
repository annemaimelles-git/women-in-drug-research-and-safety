-- Women in Drug Research and Safety
-- Demo queries for Project 1

-- Q1. Share of trials open to women, by start year and phase
SELECT dt.year AS start_year,
       t.phase,
       COUNT(DISTINCT t.nct_id)                                        AS trials,
       COUNT(DISTINCT t.nct_id) FILTER (WHERE t.eligible_sex = 'FEMALE') AS women_only,
       COUNT(DISTINCT t.nct_id) FILTER (WHERE t.eligible_sex = 'MALE')   AS men_only,
       COUNT(DISTINCT t.nct_id) FILTER (WHERE t.eligible_sex = 'ALL')    AS all_sexes,
       ROUND(100.0 * COUNT(DISTINCT t.nct_id) FILTER (WHERE t.eligible_sex IN ('ALL','FEMALE'))
             / COUNT(DISTINCT t.nct_id), 1)                            AS open_to_women_pct
FROM fact_trial_drug f
JOIN dim_trial t USING (trial_key)
JOIN dim_date dt ON dt.date_key = f.start_date_key
GROUP BY dt.year, t.phase
ORDER BY dt.year, t.phase;


-- Q2. Conditions with the lowest share of trials open to women
SELECT COALESCE(c.condition_class, c.condition_name) AS condition,
       COUNT(DISTINCT t.nct_id) AS trials,
       ROUND(100.0 * COUNT(DISTINCT t.nct_id) FILTER (WHERE t.eligible_sex IN ('ALL','FEMALE'))
             / COUNT(DISTINCT t.nct_id), 1) AS open_to_women_pct
FROM bridge_trial_condition b
JOIN dim_condition c USING (condition_key)
JOIN dim_trial t ON t.nct_id = b.nct_id AND t.is_current
GROUP BY 1
HAVING COUNT(DISTINCT t.nct_id) >= 20      -- ignore rarely studied conditions
ORDER BY open_to_women_pct ASC, trials DESC
LIMIT 20;


-- Q3. Drugs with the highest female share of adverse event reports
SELECT d.ingredient_name,
       COUNT(DISTINCT f.report_id) FILTER (WHERE p.sex IN ('Female','Male')) AS reports_known_sex,
       ROUND(100.0 * COUNT(DISTINCT f.report_id) FILTER (WHERE p.sex = 'Female')
             / NULLIF(COUNT(DISTINCT f.report_id) FILTER (WHERE p.sex IN ('Female','Male')), 0), 1) AS female_report_pct
FROM fact_adverse_event f
JOIN dim_drug d            USING (drug_key)
JOIN dim_patient_profile p USING (patient_profile_key)
GROUP BY d.ingredient_name
HAVING COUNT(DISTINCT f.report_id) FILTER (WHERE p.sex IN ('Female','Male')) >= 100
ORDER BY female_report_pct DESC
LIMIT 20;


-- Q4. Reactions reported most often in women compared to men
WITH totals AS (
  SELECT COUNT(DISTINCT f.report_id) FILTER (WHERE p.sex = 'Female') AS f_tot,
         COUNT(DISTINCT f.report_id) FILTER (WHERE p.sex = 'Male')   AS m_tot
  FROM fact_adverse_event f
  JOIN dim_patient_profile p USING (patient_profile_key)
), rx AS (
  SELECT r.meddra_pt,
         COUNT(DISTINCT f.report_id) FILTER (WHERE p.sex = 'Female') AS f_n,
         COUNT(DISTINCT f.report_id) FILTER (WHERE p.sex = 'Male')   AS m_n
  FROM fact_adverse_event f
  JOIN dim_reaction r        USING (reaction_key)
  JOIN dim_patient_profile p USING (patient_profile_key)
  GROUP BY r.meddra_pt
)
SELECT rx.meddra_pt, f_n, m_n,
       -- 1.0 = same rate in both sexes; 2.0 = twice as common in women's reports
       ROUND((f_n::numeric / f_tot) / NULLIF(m_n::numeric / m_tot, 0), 2) AS female_to_male_ratio
FROM rx CROSS JOIN totals
WHERE f_n + m_n >= 50
ORDER BY female_to_male_ratio DESC NULLS LAST
LIMIT 20;


-- Q5. Serious-outcome rate by sex and age group
SELECT p.age_band,
       p.sex,
       COUNT(DISTINCT f.report_id) AS reports,
       ROUND(100.0 * COUNT(DISTINCT f.report_id) FILTER (WHERE f.is_serious)
             / COUNT(DISTINCT f.report_id), 1) AS serious_pct
FROM fact_adverse_event f
JOIN dim_patient_profile p USING (patient_profile_key)
WHERE p.sex IN ('Female','Male')
  AND p.age_band <> 'Unknown'
GROUP BY p.age_band, p.sex
ORDER BY p.age_band, p.sex;
