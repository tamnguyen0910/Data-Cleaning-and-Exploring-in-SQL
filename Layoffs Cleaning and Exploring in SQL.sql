-- what i do in this code
	--  PART 1 : CLEAN THE DATA
		--  1 : Remove duplicates
        --  2 : Standardized the data
        --  3 : Populate Null and Blank Values
        --  4 : Remove any rows or columns that are useless
	
    -- PART 2 : Explore the date
    


--  PART 1 : CLEAN THE DATA

-- create a staging table, leave raw data untouch
Create table world_layoffs.layoffs_staging
like world_layoffs.layoffs;

insert world_layoffs.layoffs_staging
select * from world_layoffs.layoffs;

select * from world_layoffs.layoffs_staging;

-- CHECK DUPLICATES : when there is no unique identifier available
	-- Identify duplicates by counting how many times a row repeat itself before deleting them by creating a CTE
		
SELECT *
FROM (
	SELECT company, industry, total_laid_off,`date`,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging
) duplicates
WHERE 
	row_num > 1;
    
-- since MySQL does not allow to perform update on CTE (delete is an update order) but Microsoft SQL Server does
	-- so we create a staging 2 table and adding the row_num column to this table and then delete duplicates from this table
	-- instead of writting all out, we can just right click on the layoffs_staging table > Copy to Clipboard > Create Statement and then modiify it
        
alter table world_layoffs.layoffs_staging add row_num INT;

create table world_layoffs.layoffs_staging2 (
`company` text,
`location`text,
`industry`text,
`total_laid_off` INT,
`percentage_laid_off` text,
`date` text,
`stage`text,
`country` text,
`funds_raised_millions` int,
row_num INT
);

INSERT INTO `world_layoffs`.`layoffs_staging2`
(`company`,
`location`,
`industry`,
`total_laid_off`,
`percentage_laid_off`,
`date`,
`stage`,
`country`,
`funds_raised_millions`,
`row_num`)
SELECT `company`,
`location`,
`industry`,
`total_laid_off`,
`percentage_laid_off`,
`date`,
`stage`,
`country`,
`funds_raised_millions`,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging;
        
 -- before delete, make sure that you are not in safe mode : Edit > Preferences > SQL Editors > un tick safe mode then restart MySQL      
Delete
from world_layoffs.layoffs_staging2
where row_num > 1;

-- here is the cleanned table
select *
from world_layoffs.layoffs_staging2;

-- STANDARDIZING DATA : column by column

-- Comany column
-- Remove blank space before text value

-- as always view the result before update
select company, trim(company)
from world_layoffs.layoffs_staging2;

-- then update
update world_layoffs.layoffs_staging2
set company = trim(company);


-- industry column
-- see if there are multiple names to call one industry 

select distinct industry
from world_layoffs.layoffs_staging2;

-- we see blank , null, CryptoCurrency and Crypto Currency

-- always see things before change things
select *
from world_layoffs.layoffs_staging2
where industry like 'Crypto%';

-- then update 

update world_layoffs.layoffs_staging2
set industry = 'Crypto'
where industry like 'Crypto%';

-- Location column
-- see if there are any problem 

select distinct location
from world_layoffs.layoffs_staging2
order by 1;

-- found 'DÃ¼sseldorf' which shoule be 'Düsseldorf' ; 'FlorianÃ³polis' which should be 'Florianópolis' and 'MalmÃ¶' which should be 'Malmö'
-- then update
select distinct location
from world_layoffs.layoffs_staging2
where location like 'DÃ¼sseldorf';

update world_layoffs.layoffs_staging2
set location = 'Düsseldorf'
where location like 'DÃ¼sseldorf';

select distinct location
from world_layoffs.layoffs_staging2
where location like 'FlorianÃ³polis';

update world_layoffs.layoffs_staging2
set location = 'Florianópolis'
where location like 'FlorianÃ³polis';

select distinct location
from world_layoffs.layoffs_staging2
where location like 'MalmÃ¶';

update world_layoffs.layoffs_staging2
set location = 'Malmö'
where location like 'MalmÃ¶';


-- also found some locations end with a dot : here is the first methode using a condition (like If)
update world_layoffs.layoffs_staging2
set location = case
when right (location,1) ='.' then left(location,length(location)-1)
else location
end;

-- Coubtry column
select distinct country
from world_layoffs.layoffs_staging2;

-- we also noticed that there are some end with an dot
-- here we use another methode : TRAILING

update world_layoffs.layoffs_staging2
set country = trim(trailing '.' from country);

-- Date column : we see that it is in text format and there is blank sometimes in the beginning
select `date`, str_to_date(`date`,'%m/%d/%Y')
from world_layoffs.layoffs_staging2;

update world_layoffs.layoffs_staging2
set `date` = str_to_date(`date`,'%m/%d/%Y');

-- the code above fixes the problem of blank and standardized the data in the date column, but the column is still in text format
alter table world_layoffs.layoffs_staging2
modify column `date` date;


	-- POPULATE NULL AND BLANK VALUES
    
-- the industry column has some blank and null, we'll try to populate them if possible

-- here we identifie which companys are missing its industry information
select distinct company
from world_layoffs.layoffs_staging2
where industry is null or industry = '';

-- luckily we only have 4 companies : Airbnb ; Bally's Interactive ; Carvana ; Juul
-- we'll try to see if the industry information if already available for these companies in the table

select company, location, industry
from world_layoffs.layoffs_staging2
where company = 'Airbnb' or company = 'Bally''s Interactive' or company = 'Carvana' or company ='Juul';

-- we see that Airbnb, Carvana and Juul already have industry's information in the table, too bad it is not the case for Bally's Interactive
-- so we'll populate Airbnb, Carvana and Juul 's industry information

-- first we'ill transform all blank into null

update world_layoffs.layoffs_staging2
set industry = null
where industry = '';

select t1.industry , t2.industry
from world_layoffs.layoffs_staging2 t1
join world_layoffs.layoffs_staging2 t2
	on t1.company = t2.company
where t1.industry is null and t2.industry is not null;

update world_layoffs.layoffs_staging2 t1
join world_layoffs.layoffs_staging2 t2
on t1.company = t2.company
set t1.industry = t2.industry
where t1.industry is null and t2.industry is not null;

-- now we'll delete rows that are useless (only when we are 100% sure and it is the case)

delete
from world_layoffs.layoffs_staging2
where total_laid_off is null and percentage_laid_off is null;

-- now we drop the row_num column which we created to identify duplicates, but now it is useless
select * 
from world_layoffs.layoffs_staging2;

alter table world_layoffs.layoffs_staging2
drop column row_num;


-- PART 2 : Explore the date

-- Max of total laid off
select max(total_laid_off), min(total_laid_off)
from world_layoffs.layoffs_staging2;

-- which country laid off the most ?
select country, sum(total_laid_off)
from world_layoffs.layoffs_staging2
group by country
order by 2 desc;

-- which industry laid off the most ?
select industry, sum(total_laid_off)
from world_layoffs.layoffs_staging2
group by industry
order by 2 desc;

-- At what year was the laid off most severe ? keep in mind that this data only covers till april 2023
select year(`date`), sum(total_laid_off)
from world_layoffs.layoffs_staging2
group by year(`date`)
order by 2 desc;

 -- at which stage that laid off is most commonly happen ?
select stage, sum(total_laid_off)
from world_layoffs.layoffs_staging2
group by stage
order by 2 desc; 

-- total laid off accumulation by month
with rolling_total as
(select substring(`date`,1,7) as `Month`, sum(total_laid_off) as total_off
 from world_layoffs.layoffs_staging2
 where substring(`date`,1,7) is not null
 group by `Month`
 order by 1 asc
)
select `Month`, total_off, sum(total_off) over(order by `Month`) as laid_off_accumulation
from rolling_total;

-- Top 3 companies laid off the least per year ?
with CTE1 as
(
select company, year(`date`) as Years, sum(total_laid_off) as total_laid_off
from world_layoffs.layoffs_staging2
group by company, year(`date`)
)
, CTE2 as 
( 
select company, Years, total_laid_off, dense_rank() over(partition by Years order by total_laid_off ASC) as Ranking
from CTE1
)

select *
from CTE2
where Years is not null
and Ranking <=3
order by Years ASC, Ranking ASC;

-- Top 3 companies laid off the most per year ?
with CTE1 as
(
select company, year(`date`) as Years, sum(total_laid_off) as total_laid_off
from world_layoffs.layoffs_staging2
group by company, year(`date`)
)
, CTE2 as 
( 
select company, Years, total_laid_off, dense_rank() over(partition by Years order by total_laid_off DESC) as Ranking
from CTE1
)

select *
from CTE2
where Years is not null
and Ranking <=3
order by Years desc, Ranking ASC;

































