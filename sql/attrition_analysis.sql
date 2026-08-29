
-- FILE 2: ADVANCED RISK SCORING & HIGH-RISK RETENTION COHORTS


-- 1. Peer-Pay Benchmarking & Combined Risk Scoring
-- Benchmarks monthly income against peer average per (JobRole, JobLevel)
WITH peer_pay_benchmarks AS (
    SELECT 
        EmployeeNumber,
        JobRole,
        JobLevel,
        MonthlyIncome,
        OverTime,
        EnvironmentSatisfaction,
        WorkLifeBalance,
        Attrition,
        AVG(MonthlyIncome) OVER(PARTITION BY JobRole, JobLevel) AS avg_peer_income
    FROM hr_employee_attrition
),
flagged_risk_factors AS (
    SELECT 
        EmployeeNumber,
        JobRole,
        JobLevel,
        MonthlyIncome,
        avg_peer_income,
        Attrition,
        (
            (CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END) +
            (CASE WHEN WorkLifeBalance <= 2 THEN 1 ELSE 0 END) +
            (CASE WHEN MonthlyIncome < (0.85 * avg_peer_income) THEN 1 ELSE 0 END)
        ) AS risk_score
    FROM peer_pay_benchmarks
)
SELECT 
    risk_score,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS total_leavers,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS attrition_rate_pct
FROM flagged_risk_factors
GROUP BY risk_score
ORDER BY risk_score ASC;

-- 2. Create Temporary Table for Multi-Factor Flagging
DROP TABLE IF EXISTS factor_flags;

CREATE TEMPORARY TABLE factor_flags AS
SELECT 
    EmployeeNumber,
    Department,
    JobRole,
    JobLevel,
    YearsAtCompany, 
    Attrition,
    
    -- Burnout Risk Indicators
    (CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END) AS flag_overtime,
    (CASE WHEN WorkLifeBalance <= 2 THEN 1 ELSE 0 END) AS flag_low_wlb,
    (CASE WHEN DistanceFromHome > 20 THEN 1 ELSE 0 END) AS flag_long_commute,

    -- Compensation & Stagnation Indicators
    (CASE WHEN MonthlyIncome < (0.85 * AVG(MonthlyIncome) OVER(PARTITION BY JobRole, JobLevel)) THEN 1 ELSE 0 END) AS flag_underpaid,
    (CASE WHEN YearsSinceLastPromotion >= 4 THEN 1 ELSE 0 END) AS flag_no_promotion,

    -- Environment & Culture Indicators
    (CASE WHEN EnvironmentSatisfaction <= 2 THEN 1 ELSE 0 END) AS flag_low_environment,
    (CASE WHEN JobSatisfaction <= 2 THEN 1 ELSE 0 END) AS flag_low_job_satisfaction
    
FROM hr_employee_attrition;

-- 3. Composite Risk Category Analysis
-- A. Burnout Impact Assessment
SELECT 
    (flag_overtime + flag_low_wlb + flag_long_commute) AS burnout_score,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS attrition_pct
FROM factor_flags
GROUP BY burnout_score
ORDER BY burnout_score;

-- B. Stagnation & Pay Impact Assessment
SELECT 
    (flag_underpaid + flag_no_promotion) AS stagnation_score,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS attrition_pct
FROM factor_flags
GROUP BY stagnation_score
ORDER BY stagnation_score;

-- C. Dissatisfaction Assessment
SELECT 
    (flag_low_environment + flag_low_job_satisfaction) AS dissatisfaction_score,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS attrition_pct
FROM factor_flags
GROUP BY dissatisfaction_score
ORDER BY dissatisfaction_score;

-- 4. Active High-Risk Cohort Identification (For HR Action)
-- Cohort 1: At-Risk Veterans (Tenure >= 5 yrs & Low Satisfaction)
SELECT 
    'At-Risk Veterans' AS cohort_name,
    Department,
    JobRole,
    COUNT(*) AS current_active_employees
FROM hr_employee_attrition
WHERE Attrition = 'No' 
  AND YearsAtCompany >= 5 
  AND JobSatisfaction <= 2
GROUP BY Department, JobRole;

-- Cohort 2: At-Risk Veterans + Underpaid
SELECT 
    'At-Risk Veterans (Underpaid)' AS cohort_name,
    Department,
    JobRole,
    COUNT(*) AS current_active_employees
FROM factor_flags
WHERE Attrition = 'No' 
  AND YearsAtCompany >= 5 
  AND flag_low_job_satisfaction = 1
  AND flag_underpaid = 1
GROUP BY Department, JobRole;

-- Cohort 3: Stagnant High-Performers (No promotion >= 4 yrs, Rating = 4)
SELECT 
    'Stagnant High-Performers' AS cohort_name,
    Department,
    JobRole,
    COUNT(*) AS current_active_employees
FROM hr_employee_attrition
WHERE Attrition = 'No' 
  AND YearsSinceLastPromotion >= 4
  AND PerformanceRating = 4
GROUP BY Department, JobRole;
