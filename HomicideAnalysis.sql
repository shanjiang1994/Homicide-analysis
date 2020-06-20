#########################   HOMICIDE ANALYSIS    ########################
########################    AUTHOR : SHAN JIANG   ########################


###########       CREATE SCHEMA       ###############
-- DROP SCHEMA IF EXISTS Homicide_report;
-- CREATE SCHEMA Homicide_report;
USE Homicide_report;

# IMPORT DATA 
-- Table data import wizard

# CHECK DATASET
SELECT * FROM raw_dataset LIMIT 10;
DESCRIBE raw_dataset;

# MAKE A COPY OF THE RAW DATASET
DROP TABLE IF EXISTS raw_data_copy;
CREATE TABLE raw_data_copy(SELECT * FROM raw_dataset);
SELECT * FROM raw_data_copy;




###############     DATA MANIPULATION       ###############

# CREATE COUNTY QUERY
SELECT
CASE 
    WHEN  CNTYFIPS LIKE 'District of Columbia' THEN 'District of Columbia'
    ELSE substring(CNTYFIPS,1,length(CNTYFIPS)-4 )
END
FROM raw_data_copy;


# COUNTY
UPDATE  raw_data_copy
SET CNTYFIPS = CASE
                   WHEN  CNTYFIPS like 'District of Columbia' then 'District of Columbia'
                   ELSE  substring(CNTYFIPS,1,length(CNTYFIPS)-4 )
			   END;
               
               
SELECT CNTYFIPS FROM raw_data_copy;


# PEOPLE ID
alter table raw_data_copy add Offender_id varchar(50);
alter table raw_data_copy add Victim_id varchar(50);
update raw_data_copy set Victim_id = uuid_short(), Offender_id = uuid_short();
SELECT Victim_id FROM raw_data_copy;






######################   DATA BASE DESIGN    ##########################
SET FOREIGN_KEY_CHECKS = 0;

# CREATE CASE_INFO TABLE
DROP TABLE IF EXISTS CASE_INFO;
CREATE TABLE CASE_INFO(
case_id           INT    auto_increment,
Agencytype        VARCHAR(100),
Homicidetype      VARCHAR(100),
Source            VARCHAR(3),
Weapon            VARCHAR(100),
Year              INT,
Month             VARCHAR(10),
City              VARCHAR(50),
County            VARCHAR(50),
State             VARCHAR(50),
Solved            VARCHAR(3),
PRIMARY KEY (case_id)
); # we need to alter the table by adding foregin key from the relathionship ID

# INSERT DATA
INSERT INTO CASE_INFO(Agencytype, Homicidetype,Source,Weapon,Year,Month,City,County,State,Solved) 
SELECT Agentype, Homicide, Source, Weapon, Year, Month, Agency, CNTYFIPS, State, Solved
FROM raw_data_copy;

# CHECK RESULT
SELECT * FROM CASE_INFO;

# CREATE PERSON TABLE
DROP TABLE IF EXISTS person;
CREATE TABLE person (
person_id       VARCHAR(50) UNIQUE NOT NULL, 
age             INT(11), 
gender             VARCHAR(10), 
race            VARCHAR(50), 
designation     VARCHAR (10),
PRIMARY KEY (person_id)
);
# INSERT DATA
INSERT INTO person SELECT Victim_id, VicAge, VicSex, VicRace, "Victim" FROM raw_data_copy;
INSERT INTO person SELECT Offender_id, OffAge, OffSex, OffRace, "Offender" FROM raw_data_copy;

# CHECK RESULT
SELECT * FROM person LIMIT 10; 


# CREATE RELATIONSHIP TABLE
DROP TABLE IF EXISTS victim_offender_relationship;
CREATE TABLE victim_offender_relationship (
case_id           INT,
victim_id         VARCHAR(50), 
offender_id       VARCHAR(50), 
relationship      VARCHAR(50),
PRIMARY KEY (case_id)
);

# INSERT DATA

INSERT INTO victim_offender_relationship(case_id,victim_id,offender_id,relationship) 
############# window function cross quary from tow table ##################
with a1 as (
select CASE_INFO.* , row_number() over (order by case_id) r1 from CASE_INFO
),
b1 as (
select raw_data_copy.* , row_number() over (order by Victim_id) r1 from raw_data_copy
)
select a1.case_id, b1.Victim_id, b1.Offender_id, b1.Relationship 
from b1 
left join a1
on b1.r1 = a1.r1;


# CHECK RESULT
SELECT * FROM victim_offender_relationship LIMIT 10;


# ADD TABLE CONSTRIANT
ALTER TABLE victim_offender_relationship ADD FOREIGN KEY (case_id) REFERENCES CASE_INFO(case_id) ON DELETE CASCADE;
ALTER TABLE victim_offender_relationship ADD FOREIGN KEY (victim_id) REFERENCES person(person_id) ON DELETE CASCADE;
ALTER TABLE victim_offender_relationship ADD FOREIGN KEY (offender_id) REFERENCES person(person_id) ON DELETE CASCADE;

# Drop raw_data_copy
DROP TABLE IF EXISTS raw_data_copy;

SET FOREIGN_KEY_CHECKS = 1;
#################     Now database is logically created      ################### 




########################      DATA ANALYSIS        ########################## 
-- How many cases recorded over time
SELECT count(DISTINCT case_id) FROM CASE_INFO;

-- Riskiest state
SELECT state, count(*) AS total_crimes
FROM CASE_INFO 
GROUP BY state
ORDER BY total_crimes DESC;

-- clearance rate
SELECT state, (sum(CASE WHEN solved = 'Yes' THEN 1 ELSE 0 END) / count(*)) * 100 AS clearance_rate 
FROM CASE_INFO 
GROUP BY state 
ORDER BY clearance_rate DESC;

-- relationship 
SELECT relationship, COUNT(relationship) AS case_count, COUNT(relationship)*100/(SELECT COUNT(*) FROM victim_offender_relationship) AS 'percentage(%)'
FROM  victim_offender_relationship
GROUP BY relationship
ORDER BY case_count DESC;




-- gender
SELECT 
C.weapon AS Weapon, 
(sum(case when P.gender = 'Male' then 1 end)/count(*))*100 as 'Male %', 
(sum(case when P.gender = 'Female' then 1 end)/count(*))*100 as 'Female %',
(sum(case when P.gender = 'Unknown' then 1 end)/count(*))*100 as Unknown
FROM victim_offender_relationship V 
LEFT JOIN CASE_INFO C ON V.case_id = C.case_id
LEFT JOIN person P ON P.person_id = V.offender_id
GROUP BY Weapon
Order by `Male %` desc,`Female %` desc ;



-- gender2
select p1.gender as `Victim gender`, p2.gender as `Offender gender`, count(*) as `Total`, 
count(*) * 100 / (select count(*) from victim_offender_relationship) as Percentage
from victim_offender_relationship r
join person p1 on r.victim_id = p1.person_id
join person p2 on r.offender_id = p2.person_id
where p1.gender != 'Unknown' and p2.gender != 'Unknown'
group by `Victim gender`, `Offender gender`
order by `Total` desc;



-- race
SELECT 
C.weapon AS Weapon, 
(sum(case when P.race = 'White' then 1 end)/count(*))*100 as 'White %', 
(sum(case when P.race = 'Black' then 1 end)/count(*))*100 as 'Black %',
(sum(case when P.race = 'Asian' then 1 end)/count(*))*100 as 'Asian %',
(sum(case when P.race = 'American Indian or Alaskan Native' then 1 end)/count(*))*100 as 'American Indian or Alaskan Native %',
(sum(case when P.race = 'Native Hawaiian or Pacific Islander' then 1 end)/count(*))*100 as 'Native Hawaiian or Pacific Islander %',
(sum(case when P.race = 'Unknown' then 1 end)/count(*))*100 as Unknown
FROM victim_offender_relationship V 
LEFT JOIN CASE_INFO C ON V.case_id = C.case_id
LEFT JOIN person P ON P.person_id = V.offender_id
GROUP BY Weapon;

-- race 2
select p1.race as `Victim race`, p2.race as `Offender race`, count(*) * 100 / (select count(*) from CASE_INFO) as `Total %`
from victim_offender_relationship r
join person p1 on r.victim_id = p1.person_id
join person p2 on r.offender_id = p2.person_id
where p1.race != 'Unknown' and p2.race != 'Unknown'
group by `Victim race`, `Offender race`
order by `Total %` desc;


--  weapon
select weapon, count(weapon)* 100/ (select count(*) from CASE_INFO)  as `Total %`
from CASE_INFO
group by weapon
order by `Total %` desc;

-- month
select month as Month, count(*) as `Number of incidents`, count(*) * 100 / (select count(*) from CASE_INFO) as `Total %`
from CASE_INFO
group by Month
order by `Number of incidents` desc;