SELECT *
FROM hr_employee_attrition;

ALTER TABLE hr_employee_attrition
RENAME COLUMN ï»¿Age TO Age;

CREATE TABLE hr_employee_attrition2
LIKE hr_employee_attrition;

INSERT hr_employee_attrition2
SELECT *
FROM hr_employee_attrition;

SELECT * 
FROM hr_employee_attrition2;

SELECT EmployeeNumber,row_number() OVER()
FROM hr_employee_attrition2;

SELECT Department, AVG(MonthlyIncome)
FROM hr_employee_attrition2
GROUP BY Department;

SELECT Attrition,COUNT(*)
FROM hr_employee_attrition2
GROUP BY Attrition;

WITH attrition_summary AS (
    SELECT 
        COUNT(*) AS total_employees,
        SUM(CASE 
        WHEN Attrition = 'Yes' THEN 1 ELSE 0 
        END) AS total_leavers
    FROM hr_employee_attrition
)
SELECT 
    total_employees,
    total_leavers,
    ROUND((total_leavers * 100.0) / total_employees, 2) AS attrition_rate_pct
FROM attrition_summary;

WITH attrition_summary AS (
    SELECT 
        COUNT(*) AS total_employees,
        SUM(CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END) AS Over_timer
    FROM hr_employee_attrition
)
SELECT 
    total_employees,
    Over_timer,
    ROUND((Over_timer * 100.0) / total_employees, 2) AS OVERTIMER_rate_pct
FROM attrition_summary;


WITH attrition_summary AS (
    SELECT 
        COUNT(*) AS total_employees,OverTime,
        SUM(CASE 
        WHEN Attrition = 'Yes' THEN 1 ELSE 0 
        END) AS total_leavers
    FROM hr_employee_attrition
    GROUP BY OverTime
)
SELECT 
    total_employees,
    total_leavers,
   OverTime,
    ROUND((total_leavers * 100.0) / total_employees, 2) AS attrition_rate_pct
FROM attrition_summary;


SELECT Department,SUM(EmployeeCount), AVG(EnvironmentSatisfaction)
FROM hr_employee_attrition2
GROUP BY Department;

SELECT Department, COUNT(*) AS total_employees, SUM(CASE 
WHEN EnvironmentSatisfaction = 1 THEN 1 ELSE 0
END) AS poor_env_count,
SUM(CASE 
        WHEN Attrition = 'Yes' THEN 1 ELSE 0 
        END) AS total_leavers
FROM hr_employee_attrition2
GROUP BY Department;



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


WITH factor_flags AS (
    SELECT 
        EmployeeNumber,
        Department,
        JobRole,
        Attrition,
        
        -- 1. BURNOUT FLAGS
        (CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END) AS flag_overtime,
        (CASE WHEN WorkLifeBalance <= 2 THEN 1 ELSE 0 END) AS flag_low_wlb,
        (CASE WHEN DistanceFromHome > 20 THEN 1 ELSE 0 END) AS flag_long_commute,

        -- 2. COMPENSATION & STAGNATION FLAGS
        (CASE WHEN MonthlyIncome < (0.85 * AVG(MonthlyIncome) OVER(PARTITION BY JobRole, JobLevel)) THEN 1 ELSE 0 END) AS flag_underpaid,
        (CASE WHEN YearsSinceLastPromotion >= 4 THEN 1 ELSE 0 END) AS flag_no_promotion,

        -- 3. ENVIRONMENT & CULTURE FLAGS
        (CASE WHEN EnvironmentSatisfaction <= 2 THEN 1 ELSE 0 END) AS flag_low_environment,
        (CASE WHEN JobSatisfaction <= 2 THEN 1 ELSE 0 END) AS flag_low_job_satisfaction
        
    FROM hr_employee_attrition
)
SELECT 
    (flag_overtime + flag_low_wlb + flag_long_commute) AS burnout_score,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS attrition_pct
FROM factor_flags
GROUP BY burnout_score
ORDER BY burnout_score;

-- creating temp table because of the restriction of cte.
DROP TABLE IF EXISTS factor_flags;

CREATE TEMPORARY TABLE factor_flags AS
SELECT 
    EmployeeNumber,
    Department,
    JobRole,
    JobLevel,
    YearsAtCompany, 
    Attrition,
    
    -- 1. BURNOUT FLAGS
    (CASE WHEN OverTime = 'Yes' THEN 1 ELSE 0 END) AS flag_overtime,
    (CASE WHEN WorkLifeBalance <= 2 THEN 1 ELSE 0 END) AS flag_low_wlb,
    (CASE WHEN DistanceFromHome > 20 THEN 1 ELSE 0 END) AS flag_long_commute,

    -- 2. COMPENSATION & STAGNATION FLAGS
    (CASE WHEN MonthlyIncome < (0.85 * AVG(MonthlyIncome) OVER(PARTITION BY JobRole, JobLevel)) THEN 1 ELSE 0 END) AS flag_underpaid,
    (CASE WHEN YearsSinceLastPromotion >= 4 THEN 1 ELSE 0 END) AS flag_no_promotion,

    -- 3. ENVIRONMENT & CULTURE FLAGS
    (CASE WHEN EnvironmentSatisfaction <= 2 THEN 1 ELSE 0 END) AS flag_low_environment,
    (CASE WHEN JobSatisfaction <= 2 THEN 1 ELSE 0 END) AS flag_low_job_satisfaction
    
FROM hr_employee_attrition;
	
    SELECT *
    FROM factor_flags;

SELECT 
    (flag_overtime + flag_low_wlb + flag_long_commute) AS burnout_score,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2)  AS attrition_pct
FROM factor_flags
GROUP BY burnout_score
ORDER BY burnout_score;

SELECT 
    (flag_underpaid + flag_no_promotion) AS stagnation_score,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS attrition_pct
FROM factor_flags
GROUP BY stagnation_score
ORDER BY stagnation_score;

SELECT 
    (flag_low_environment+ flag_low_job_satisfaction) AS dissatisfication_factor,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
    ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS attrition_pct
FROM factor_flags
GROUP BY dissatisfication_factor
ORDER BY dissatisfication_factor;

SELECT 
    'At-Risk Veterans (YearsAtCompany >= 5, Low Satisfaction)' AS cohort_name,
    Department,
    JobRole,
    COUNT(*) AS current_employee_count
FROM hr_employee_attrition
WHERE Attrition = 'No' 
  AND YearsAtCompany >= 5 
  AND JobSatisfaction <= 2
 
GROUP BY Department, JobRole;

SELECT 
    'At-Risk Veterans (YearsAtCompany >= 5, Low Satisfaction, Underpaid)' AS cohort_name,
    Department,
    JobRole,
    COUNT(*) AS current_employee_count
FROM factor_flags
WHERE Attrition = 'No' 
  AND YearsAtCompany >= 5 
  AND flag_low_job_satisfaction = 1
  AND flag_underpaid = 1
GROUP BY Department, JobRole;


SELECT 
    'Stagnant High-Performers (No Promotion >= 4 yrs)' AS cohort_name,
    Department,
    JobRole,
    COUNT(*) AS current_employee_count
FROM hr_employee_attrition
WHERE Attrition = 'No' 
  AND YearsSinceLastPromotion >= 4
  AND PerformanceRating = 4
GROUP BY Department, JobRole;

SELECT *
FROM hr_employee_attrition2;

