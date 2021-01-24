
SELECT TOP 100 * FROM DBO.METER_DATA_CLEANED WITH (NOLOCK); -- 377775
SELECT TOP 100 * FROM DBO.MOER_DATA_CLEANED WITH (NOLOCK);  -- 113948
SELECT TOP 100 * FROM DBO.METER_DATA_CLEANED_PER_DAY WITH (NOLOCK); -- 16425




SELECT TOP 100 * FROM DBO.ENERGY_PER_REGION_COST_INITIAL;


SELECT * FROM DBO.ENERGY_PER_REGION_COST_INITIAL


-- Analytics Component
-- Get the cost per region per MWH as baseline for what we can reduce
DROP TABLE  DBO.ENERGY_PER_REGION_COST_INITIAL;
SELECT ENERGY_USAGE.CITY, ENERGY_USAGE.DATE_AS_DATE, EMISSION_COST.MOER, ENERGY_CONSUMED_IN_MWH, 
EMISSION_COST.MOER/ENERGY_CONSUMED_IN_MWH  AS COST_PER_MWH
INTO DBO.ENERGY_PER_REGION_COST_INITIAL
FROM (SELECT CITY, DATE_AS_DATE, SUM(TOTAL_JOULES)* 0.000000000277778 AS ENERGY_CONSUMED_IN_MWH FROM DBO.METER_DATA_CLEANED 
-- Conversion factor from Joules to MegaWatHour (2.77778e-10) = 0.000000000277778
GROUP BY CITY, DATE_AS_DATE) ENERGY_USAGE
INNER JOIN DBO.MOER_DATA_CLEANED EMISSION_COST
ON ENERGY_USAGE.CITY = EMISSION_COST.CITY AND ENERGY_USAGE.DATE_AS_DATE = EMISSION_COST.DATE_AS_DATE;



-- Calculate per region the MWH saved if we implement a solution
DROP TABLE DBO.ALL_PATHS_INITIAL_METHOD_REDUCE_USAGE;
SELECT DISTINCT
A.CITY, A.BUILDING_TYPE, A.DT, A.DATE_AS_DATE,
TOTAL_JOULES*MULTIPLIER*A.ENERGY_CONSUMED_IN_MWH AS NEW_ENERGY_USAGE,
A.ENERGY_CONSUMED_IN_MWH - (A.TOTAL_JOULES*ATTACK.MULTIPLIER*0.000000000277778) AS ENERGY_SAVED_IN_MWH,
C.COST_PER_MWH,
C.COST_PER_MWH*(A.ENERGY_CONSUMED_IN_MWH - (A.TOTAL_JOULES*MULTIPLIER*0.000000000277778)) AS LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY
--MAXIMUM_COST_PER_MWH,
--MINIMUM_COST_PER_MWH,
--(E.MAXIMUM_COST_PER_MWH - F.MINIMUM_COST_PER_MWH)*D.ENERGY_IN_MWH_WITH_FLEXIBLITY AS LBS_OF_CO2_SAVED_BY_MOVING_ENERGY
--C.COST_PER_MWH*(A.ENERGY_CONSUMED_IN_MWH - (A.TOTAL_JOULES*MULTIPLIER*0.000000000277778)) + (E.MAXIMUM_COST_PER_MWH - F.MINIMUM_COST_PER_MWH)*D.ENERGY_IN_MWH_WITH_FLEXIBLITY AS TOTAL_CO2_SAVED
INTO DBO.ALL_PATHS_INITIAL_METHOD_REDUCE_USAGE
FROM  
(SELECT *, CAST(DATE_AS_DATE AS DATE) AS DT, TOTAL_JOULES*0.000000000277778 AS ENERGY_CONSUMED_IN_MWH  FROM DBO.METER_DATA_CLEANED) A
INNER JOIN
(SELECT 'OFFICE_LARGE' AS G, 0.75 AS MULTIPLIER 
UNION ALL SELECT 'APARTMENT_HIGH_RISE' AS G, 0.75 AS MULTIPLIER
UNION ALL SELECT 'RETAIL_STRIP_MALL' AS G, 0.75 AS MULTIPLIER) ATTACK
ON A.BUILDING_TYPE = ATTACK.G
INNER JOIN DBO.ENERGY_PER_REGION_COST_INITIAL C
ON A.DATE_AS_DATE = C.DATE_AS_DATE AND A.CITY = C.CITY;


DROP TABLE DBO.ALL_PATHS_INITIAL_METHOD_OPTIMIZE_USAGE;
SELECT DISTINCT
A.CITY, A.BUILDING_TYPE, A.DT,
MAXIMUM_COST_PER_MWH,
MINIMUM_COST_PER_MWH,
(E.MAXIMUM_COST_PER_MWH - F.MINIMUM_COST_PER_MWH)*D.ENERGY_IN_MWH_WITH_FLEXIBLITY AS LBS_OF_CO2_SAVED_BY_MOVING_ENERGY
INTO DBO.ALL_PATHS_INITIAL_METHOD_OPTIMIZE_USAGE
FROM
(SELECT *, CAST(DATE_AS_DATE AS DATE) AS DT, TOTAL_JOULES*0.000000000277778 AS ENERGY_CONSUMED_IN_MWH  FROM DBO.METER_DATA_CLEANED) A
INNER JOIN
(SELECT *, TOTAL_JOULES_PER_DAY*0.75*0.000000000277778*0.10 AS ENERGY_IN_MWH_WITH_FLEXIBLITY FROM DBO.METER_DATA_CLEANED_PER_DAY) D
ON A.BUILDING_TYPE = D.BUILDING_TYPE AND A.CITY = D.CITY AND A.DT = D.DATE
INNER JOIN
(SELECT CITY, CAST(DATE_AS_DATE AS DATE) AS DT, MAX(COST_PER_MWH) AS MAXIMUM_COST_PER_MWH FROM DBO.ENERGY_PER_REGION_COST_INITIAL
GROUP BY CITY, CAST(DATE_AS_DATE AS DATE)) E
ON D.CITY = E.CITY AND D.DATE = E.DT
INNER JOIN
(SELECT CITY, CAST(DATE_AS_DATE AS DATE) AS DT, MIN(COST_PER_MWH) AS MINIMUM_COST_PER_MWH FROM DBO.ENERGY_PER_REGION_COST_INITIAL
GROUP BY CITY, CAST(DATE_AS_DATE AS DATE)) F
ON D.CITY = F.CITY AND D.DATE = F.DT;






-- SELECT top 100 * FROM DBO.ALL_PATHS_INITIAL
DROP TABLE DBO.ALL_PATHS_FINAL;
SELECT
A.CITY, A.BUILDING_TYPE, A.DT, LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY, LBS_OF_CO2_SAVED_BY_MOVING_ENERGY,
LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY + LBS_OF_CO2_SAVED_BY_MOVING_ENERGY AS TOTAL_CO2_SAVED
INTO DBO.ALL_PATHS_FINAL
FROM 
(SELECT CITY, BUILDING_TYPE, DT, SUM(LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY) AS LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY FROM DBO.ALL_PATHS_INITIAL_METHOD_REDUCE_USAGE
GROUP BY  CITY, BUILDING_TYPE, DT) A
INNER JOIN
DBO.ALL_PATHS_INITIAL_METHOD_OPTIMIZE_USAGE B
ON A.CITY = B.CITY AND A.BUILDING_TYPE = B.BUILDING_TYPE  AND A.DT = B.DT;



SELECT 
'state,CITY,BUILDING_TYPE,DT,DATE_AS_DATE, LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY,LBS_OF_CO2_SAVED_BY_MOVING_ENERGY,TOTAL_CO2_SAVED' 
UNION ALL


SELECT 
'state,CITY,BUILDING_TYPE,DT,TOTAL_CO2_SAVED' 
UNION ALL
SELECT  DISTINCT
STATE_CODE + ',' +
CITY + ',' +
BUILDING_TYPE + ',' +
--CONVERT(NVARCHAR(100), DT, 120) + ',' +
--CONVERT(NVARCHAR(100), DATE_AS_DATE, 120) + ',' +
--CAST(LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY AS NVARCHAR(500)) + ',' +
--CAST(LBS_OF_CO2_SAVED_BY_MOVING_ENERGY AS NVARCHAR(500)) + ',' +
CAST(TOTAL_CO2_SAVED AS NVARCHAR(500)) 
FROM
(SELECT
CASE WHEN A.CITY = 'ATLANTA' THEN 'GA'
	WHEN A.CITY = 'PortAngeles' THEN 'WA'
	WHEN A.CITY = 'SanDiego' THEN 'CA'
	WHEN A.CITY = 'InternationalFalls' THEN 'MN'
	WHEN A.CITY = 'Tucson' THEN 'AZ'
	WHEN A.CITY = 'Rochester' THEN 'GA'
	WHEN A.CITY = 'NewYork' THEN 'NY'
	WHEN A.CITY = 'ElPaso' THEN 'TX'
	WHEN A.CITY = 'GreatFalls' THEN 'MT'
	WHEN A.CITY = 'Tampa' THEN 'FL'
	WHEN A.CITY = 'Seattle' THEN 'WA'
	WHEN A.CITY = 'Rochester' THEN 'NY'
	WHEN A.CITY = 'Buffalo' THEN 'NY'
	WHEN A.CITY = 'Denver' THEN 'CO' 
	END AS STATE_CODE,
A.CITY, A.BUILDING_TYPE, A.DT,  B.DATE_AS_DATE, B.LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY, LBS_OF_CO2_SAVED_BY_MOVING_ENERGY, CEILING(TOTAL_CO2_SAVED) AS TOTAL_CO2_SAVED
FROM DBO.ALL_PATHS_INITIAL_METHOD_REDUCE_USAGE B 
INNER JOIN DBO.ALL_PATHS_FINAL A
ON A.CITY = B.CITY AND A.DT = B.DT AND A.BUILDING_TYPE = B.BUILDING_TYPE 
) A


327405

SELECT COUNT(*) FROM DBO.ALL_PATHS_INITIAL_METHOD_REDUCE_USAGE




SELECT DISTINCT TOP 100  CITY 
FROM DBO.ALL_PATHS_FINAL A


 - NY


SELECT top 100 * FROM
(SELECT CITY, BUILDING_TYPE, CEILING(SUM(TOTAL_CO2_SAVED)) AS TOTAL_CO2_SAVED_IN_YEAR FROM DBO.ALL_PATHS_FINAL
GROUP BY CITY, BUILDING_TYPE) A
ORDER BY TOTAL_CO2_SAVED_IN_YEAR DESC;
--WHERE TOTAL_CO2_SAVED  = (SELECT MAX(TOTAL_CO2_SAVED) FROM DBO.ALL_PATHS_FINAL)




SELECT 
'CITY,BUILDING_TYPE,DATE_AS_DATE,NEW_ENERGY_USAGE_IN_MWH,ENERGY_SAVED_IN_MWH,COST_PER_MWH,LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY' 
UNION ALL
SELECT
CITY + ',' +  
BUILDING_TYPE + ',' +
CONVERT(VARCHAR(30), DATE_AS_DATE, 120) + ',' +
CAST(NEW_ENERGY_USAGE AS VARCHAR(50)) + ',' +
CAST(ENERGY_SAVED_IN_MWH AS VARCHAR(50))   + ',' +
CAST(COST_PER_MWH AS VARCHAR(50))   + ',' +
CAST(LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY AS VARCHAR(50))   
FROM  DBO.ALL_PATHS_INITIAL_METHOD_REDUCE_USAGE






SELECT 
'CITY,BUILDING_TYPE,DATE,MAXIMUM_COST_PER_MWH,MINIMUM_COST_PER_MWH,LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY' 
UNION ALL
SELECT
DISTINCT 
CITY + ',' +  
BUILDING_TYPE + ',' +
CONVERT(VARCHAR(30), DT, 120) + ',' +  + ',' +
CAST(MAXIMUM_COST_PER_MWH AS VARCHAR(50)) + ',' + 
CAST(MINIMUM_COST_PER_MWH AS VARCHAR(50)) + ',' + 
CAST(LBS_OF_CO2_SAVED_BY_MOVING_ENERGY AS VARCHAR(50))
FROM DBO.ALL_PATHS_INITIAL_METHOD_OPTIMIZE_USAGE
ORDER BY CITY, BUILDING_TYPE, CONVERT(VARCHAR(30), DT, 120)


SELECT
TOP 500
CITY,  
BUILDING_TYPE,
DT
INTO 
FROM DBO.ALL_PATHS_INITIAL
GROUP BY CITY, BUILDING_TYPE, DT
HAVING COUNT(DISTINCT MAXIMUM_COST_PER_MWH) > 1


SELECT COUNT(DISTINCT BUILDING_TYPE) 
FROM
(SELECT *, TOTAL_JOULES_PER_DAY*0.75*0.000000000277778*0.10 AS ENERGY_IN_MWH_WITH_FLEXIBLITY FROM DBO.METER_DATA_CLEANED_PER_DAY) D
GROUP BY CITY, BUILDING_TYPE, DATE
HAVING COUNT(DISTINCT ENERGY_IN_MWH_WITH_FLEXIBLITY) > 1




SELECT 
'state,date_string,TOTAL_CO2_SAVED' 
UNION ALL
SELECT  DISTINCT
STATE_CODE + ',' +
--CITY + ',' +
--BUILDING_TYPE + ',' +
CONVERT(NVARCHAR(100), DATE_AS_DATE, 120 ) + ',' +  -- date_string = datetime_object.strftime('%m/%d/%Y, %H:%M:%S')
--CONVERT(NVARCHAR(100), DATE_AS_DATE, 120) + ',' +
--CAST(LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY AS NVARCHAR(500)) + ',' +
--CAST(LBS_OF_CO2_SAVED_BY_MOVING_ENERGY AS NVARCHAR(500)) + ',' +
CAST(SUM(LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY) AS NVARCHAR(500)) 
FROM
(SELECT
CASE WHEN A.CITY = 'ATLANTA' THEN 'GA'
	WHEN A.CITY = 'PortAngeles' THEN 'WA'
	WHEN A.CITY = 'SanDiego' THEN 'CA'
	WHEN A.CITY = 'InternationalFalls' THEN 'MN'
	WHEN A.CITY = 'Tucson' THEN 'AZ'
	WHEN A.CITY = 'Rochester' THEN 'GA'
	WHEN A.CITY = 'NewYork' THEN 'NY'
	WHEN A.CITY = 'ElPaso' THEN 'TX'
	WHEN A.CITY = 'GreatFalls' THEN 'MT'
	WHEN A.CITY = 'Tampa' THEN 'FL'
	WHEN A.CITY = 'Seattle' THEN 'WA'
	WHEN A.CITY = 'Rochester' THEN 'NY'
	WHEN A.CITY = 'Buffalo' THEN 'NY'
	WHEN A.CITY = 'Denver' THEN 'CO' 
	END AS STATE_CODE,
A.CITY, A.BUILDING_TYPE, A.DT,  B.DATE_AS_DATE, B.LBS_OF_CO2_SAVED_BY_USING_LESSER_ENERGY, LBS_OF_CO2_SAVED_BY_MOVING_ENERGY, CEILING(TOTAL_CO2_SAVED) AS TOTAL_CO2_SAVED
FROM DBO.ALL_PATHS_INITIAL_METHOD_REDUCE_USAGE B 
INNER JOIN DBO.ALL_PATHS_FINAL A
ON A.CITY = B.CITY AND A.DT = B.DT AND A.BUILDING_TYPE = B.BUILDING_TYPE) A
GROUP BY STATE_CODE, CONVERT(NVARCHAR(100), DATE_AS_DATE, 120 ) 