-- MAJI NDOGO WATER PROJECT (Part III)

-- WEAVING THE DATA THREADS OF MAJI NDOGO'S NARRATIVE

-- 1. Managing the ERD

-- Change the relationship between `water_quality` and `visits` tables from many-to-one to one-to-one relationship.
-- This is because each visit recorded is associated with a specific water quality score.

-- 2. Intergrating the Auditor's Report

-- Create the `auditor_report` table in the database and import data to fill in.
DROP TABLE IF EXISTS `auditor_report`; -- Delete in case such a table exists 

CREATE TABLE `auditor_report` (
`location_id` VARCHAR(32),
`type_auditor_reportof_water_source` VARCHAR(64),
`true_water_source_score` int DEFAULT NULL,
`statements` VARCHAR(255)
);

-- (a). Is there a difference between the surveyors' and auditor's scores?
SELECT 	ar.location_id,
		wq.record_id,
        wq.subjective_quality_score AS surveyor_score,
		ar.true_water_source_score AS auditor_score
FROM 	visits AS v
JOIN 	water_quality AS wq
	ON v.record_id = wq.record_id
JOIN 	auditor_report AS ar
	ON v.location_id = ar.location_id
WHERE 	v.visit_count = 1 AND wq.subjective_quality_score != ar.true_water_source_score;
-- 102 disparities in scores; on the positive side 94% of the records the auditor checked were correct.

-- (b). If so, are there patterns?
-- Compare the sources
SELECT 	ar.location_id,
		wq.record_id,
        wq.subjective_quality_score AS surveyor_score,
		ar.true_water_source_score AS auditor_score,
        ws.type_of_water_source AS surveyor_source,
        ar.type_of_water_source AS auditor_source
FROM 	visits AS v
JOIN 	water_quality AS wq
	ON v.record_id = wq.record_id
JOIN 	auditor_report AS ar
	ON v.location_id = ar.location_id
JOIN 	water_source AS ws
	ON v.source_id = ws.source_id
WHERE 	v.visit_count = 1 AND wq.subjective_quality_score != ar.true_water_source_score;
-- The types of sources look the same. So, though the scores are wrong, the integrity of the source type data analysed previously is not affected.

-- 3. Linking Records to Employees

-- Where are these errors coming from?
-- Either because these workers are humans and so make mistakes; or unfortunately, someone assigned scores incorrectly on purpose.
WITH incorrect_records AS (
	SELECT 	ar.location_id,
			wq.record_id,
			e.employee_name,
			wq.subjective_quality_score AS surveyor_score,
			ar.true_water_source_score AS auditor_score
	FROM 	visits AS v
	JOIN 	water_quality AS wq
		ON v.record_id = wq.record_id
	JOIN 	auditor_report AS ar
		ON v.location_id = ar.location_id
	JOIN 	employee AS e
		ON v.assigned_employee_id = e.assigned_employee_id
	WHERE 	v.visit_count = 1 AND wq.subjective_quality_score != ar.true_water_source_score)
SELECT 	employee_name,
		COUNT(employee_name) AS number_of_errors
FROM 	incorrect_records
GROUP BY employee_name
ORDER BY 2 DESC;

-- 4. Investigating Anomalies

-- This view makes it easy to reference and makes codes more readable
CREATE VIEW incorrect_records AS (
	SELECT 	ar.location_id,
			wq.record_id,
			e.employee_name,
			wq.subjective_quality_score AS surveyor_score,
			ar.true_water_source_score AS auditor_score,
            ar.statements
	FROM 	visits AS v
	JOIN 	water_quality AS wq
		ON v.record_id = wq.record_id
	JOIN 	auditor_report AS ar
		ON v.location_id = ar.location_id
	JOIN 	employee AS e
		ON v.assigned_employee_id = e.assigned_employee_id
	WHERE 	v.visit_count = 1 AND wq.subjective_quality_score != ar.true_water_source_score);
    
-- (a). How many errors have each employee made?
WITH error_count AS (
	SELECT 	employee_name,
			COUNT(employee_name) AS number_of_errors
	FROM 	incorrect_records
	GROUP BY employee_name
	ORDER BY 2 DESC)
SELECT 	*
FROM 	error_count;

-- (b). Calculate the average number of errors
WITH error_count AS (
	SELECT 	employee_name,
			COUNT(employee_name) AS number_of_errors
	FROM 	incorrect_records
	GROUP BY employee_name
	ORDER BY 2 DESC)
SELECT 	AVG(number_of_errors) AS avg_errors
FROM 	error_count;

-- (c). Which employees have an above-average number of errors?
WITH error_count AS (
	SELECT 	employee_name,
			COUNT(employee_name) AS number_of_errors
	FROM 	incorrect_records
	GROUP BY employee_name
	ORDER BY 2 DESC)
SELECT 	employee_name, 
		number_of_errors
FROM 	error_count
WHERE 	number_of_errors > (SELECT AVG(number_of_errors) FROM error_count);

-- (d). Filter all of the records where the "suspected" employees gathered data.
WITH 
error_count AS (				-- This CTE calculates the number of mistakes each employee made
    SELECT  employee_name,
            COUNT(employee_name) AS number_of_errors
    FROM    incorrect_records
    GROUP BY employee_name
    ORDER BY 2 DESC),
suspect_list AS ( 				-- This CTE SELECTS the employees with above−average mistakes
    SELECT  employee_name,
            number_of_errors
    FROM    error_count
    WHERE   number_of_errors > (SELECT AVG(number_of_errors) FROM error_count)
    )
-- This query filters all of the records where the "suspected" employees gathered data.
SELECT  employee_name,
        location_id,
        statements
FROM    incorrect_records
WHERE   employee_name IN (SELECT employee_name FROM suspect_list);

-- (e) Check how the word 'cash' and 'corrupt' is used in the statements for the 'suspects'.
WITH 
error_count AS (				-- This CTE calculates the number of mistakes each employee made
    SELECT  employee_name,
            COUNT(employee_name) AS number_of_errors
    FROM    incorrect_records
    GROUP BY employee_name
    ORDER BY 2 DESC),
suspect_list AS ( 				-- This CTE SELECTS the employees with above−average mistakes
    SELECT  employee_name,
            number_of_errors
    FROM    error_count
    WHERE   number_of_errors > (SELECT AVG(number_of_errors) FROM error_count)
    )
SELECT  employee_name,
        location_id,
        statements
FROM    incorrect_records
WHERE   employee_name IN (SELECT employee_name FROM suspect_list) AND (statements LIKE '%cash%' OR statements LIKE '%corrupt%');

-- (f). Are there any employees in the `incorrect_records` table with statements mentioning "cash" or 'corrupt' that are not in the suspect list?
WITH 
error_count AS (				-- This CTE calculates the number of mistakes each employee made
    SELECT  employee_name,
            COUNT(employee_name) AS number_of_errors
    FROM    incorrect_records
    GROUP BY employee_name
    ORDER BY 2 DESC),
suspect_list AS ( 				-- This CTE SELECTS the employees with above−average mistakes
    SELECT  employee_name,
            number_of_errors
    FROM    error_count
    WHERE   number_of_errors > (SELECT AVG(number_of_errors) FROM error_count)
    )
SELECT  employee_name,
        location_id,
        statements
FROM    incorrect_records
WHERE   employee_name NOT IN (SELECT employee_name FROM suspect_list) AND (statements LIKE '%cash%' OR statements LIKE '%corrupt%');

/* 
Investigations Summary
The evidence against Zuriel Matembo, Malachi Mavuso, Bello Azibo and Lalitha Kaburi is as follows:
	-> They all made more mistakes than their peers on average.
	->They all have incriminating statements made against them, and only them.
NOTE: That this is not decisive proof, but it is concerning enough that we should flag it.
*/