--CY, PY, and Variance (Total Billing Amount)
SELECT 
	DATEPART(YEAR, date_of_admission) AS Year,
	ROUND(SUM(billing_amount),0) AS CY_billing_amount,
	ROUND(LAG(SUM(billing_amount)) OVER (ORDER BY DATEPART(YEAR, date_of_admission)),0) AS PY_billing_amount,
	ROUND(SUM(billing_amount) - LAG(SUM(billing_amount)) OVER (ORDER BY DATEPART(YEAR, date_of_admission)),0) AS Variance
FROM healthcare_dataset
GROUP BY DATEPART(YEAR, date_of_admission);

--Billing per visit
SELECT 
	DATEPART(YEAR, date_of_admission) AS Year,
	ROUND(AVG(billing_amount),0) AS CY_billing_per_visit,
	ROUND(LAG(AVG(billing_amount)) OVER (ORDER BY DATEPART(YEAR, date_of_admission)),0) AS PY_billing_per_visit,
	ROUND(AVG(billing_amount) - LAG(AVG(billing_amount)) OVER (ORDER BY DATEPART(YEAR, date_of_admission)),0) AS Variance
FROM healthcare_dataset
GROUP BY DATEPART(YEAR, date_of_admission);

--Unique Patients
SELECT 
	DATEPART(YEAR, date_of_admission) AS Year,
	COUNT(DISTINCT uniqueid) AS CY_patients,
	LAG(COUNT(DISTINCT uniqueid)) OVER (ORDER BY DATEPART(YEAR, date_of_admission)) AS PY_patients,
	COUNT(DISTINCT uniqueid) - LAG(COUNT(DISTINCT uniqueid)) OVER (ORDER BY DATEPART(YEAR, date_of_admission)) AS Variance
FROM healthcare_dataset
GROUP BY DATEPART(YEAR, date_of_admission);

--Average LOS (Days)
SELECT 
	DATEPART(YEAR, date_of_admission) AS Year,
	AVG(DATEDIFF(DAY, date_of_admission, discharge_date)) AS CY_average_LOS,
	LAG(AVG(DATEDIFF(DAY, date_of_admission, discharge_date))) OVER (ORDER BY DATEPART(YEAR, date_of_admission)) AS PY_average_LOS,
	AVG(DATEDIFF(DAY, date_of_admission, discharge_date)) - LAG(AVG(DATEDIFF(DAY, date_of_admission, discharge_date))) 
		OVER (ORDER BY DATEPART(YEAR, date_of_admission)) AS Variance
FROM healthcare_dataset
GROUP BY DATEPART(YEAR, date_of_admission);


--Which doctor generated the highest total billing amount for each year?
WITH DoctorBillingSummary AS (
		SELECT 
			DATEPART(YEAR, date_of_admission) AS year,
			doctor,
			ROUND(SUM(billing_amount),0) AS total_billing,
			DENSE_RANK() OVER (
				PARTITION BY DATEPART(YEAR, date_of_admission) 
				ORDER BY SUM(billing_amount) DESC
			) AS billing_rank
		FROM healthcare_dataset
		GROUP BY DATEPART(YEAR, date_of_admission), doctor
	)
SELECT
	'In year ' + CAST(year AS VARCHAR) + ', doctor ' + doctor + 
	' generated the most amount of revenue with $' + 
    CAST(total_billing AS VARCHAR) AS Summary
FROM DoctorBillingSummary
WHERE billing_rank = 1
ORDER BY year;


--What percentage of patients, by admission type, were admitted each year?
SELECT 
    DATEPART(YEAR, date_of_admission) AS Year,
    admission_type,
    COUNT(*) AS patient_count,
    (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER (PARTITION BY DATEPART(YEAR, date_of_admission)) AS percentage
FROM healthcare_dataset
GROUP BY DATEPART(YEAR, date_of_admission), admission_type
ORDER BY Year, admission_type;


--What is the distribution of prescribed medications by year?
SELECT 
    DATEPART(YEAR, date_of_admission) AS Year,
    medication,
    COUNT(*) AS patient_count,
    (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER (PARTITION BY DATEPART(YEAR, date_of_admission)) AS percentage
FROM healthcare_dataset
GROUP BY DATEPART(YEAR, date_of_admission), medication
ORDER BY Year, medication;


--Who are the top 5 doctors with the largest increase in billings compared to the prior year?
WITH YearlyBilling AS (
    SELECT 
        DATEPART(YEAR, date_of_admission) AS billing_year,
        doctor,
        SUM(billing_amount) AS total_billing
    FROM healthcare_dataset
    GROUP BY DATEPART(YEAR, date_of_admission), doctor
),

YoYBilling AS (
    SELECT 
        y1.billing_year AS current_year,
        y1.doctor,
        y1.total_billing AS current_year_billing,
        y2.total_billing AS previous_year_billing,
        ROUND(y1.total_billing - y2.total_billing,0) AS yoy_change
    FROM YearlyBilling y1
    LEFT JOIN YearlyBilling y2 
        ON y1.doctor = y2.doctor 
        AND y1.billing_year = y2.billing_year + 1
),

FilteredResults AS (
    SELECT 
        current_year,
        doctor,
        current_year_billing,
        previous_year_billing,
        yoy_change,
        ROW_NUMBER() OVER(PARTITION BY current_year ORDER BY yoy_change DESC) AS yoy_change_rank
    FROM YoYBilling
    WHERE previous_year_billing >= 1
)

SELECT 
    current_year,
    doctor,
    yoy_change,
	yoy_change_rank
FROM FilteredResults
WHERE yoy_change_rank <= 5
ORDER BY current_year, yoy_change DESC;

-- Who are the top 5 doctors by average cost per visit for each year?
WITH ranked_doctors AS (
    SELECT 
        DATEPART(YEAR, date_of_admission) AS Year,
        doctor,
        AVG(billing_amount) AS average_billing,
        DENSE_RANK() OVER (
            PARTITION BY DATEPART(YEAR, date_of_admission) 
            ORDER BY AVG(billing_amount) DESC
        ) AS avg_billing_rank
    FROM healthcare_dataset
    GROUP BY DATEPART(YEAR, date_of_admission), doctor
)

SELECT 
    Year,
    doctor,
    average_billing,
    avg_billing_rank
FROM ranked_doctors
WHERE avg_billing_rank <= 5
ORDER BY Year, avg_billing_rank;