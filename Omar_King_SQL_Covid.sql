----Exploring Covid Deaths and Vaccinations Data
--Select * 
--  FROM [AI_OMAR].[dbo].[Covid_Vaccinations]
--  ORDER BY 3,4

--Select * 
--  FROM [AI_OMAR].[dbo].[Covid_Deaths]
--  ORDER BY 3,4

---- Just the data we're interested in
--SELECT location, date, total_cases, new_cases, total_deaths, population
--FROM [AI_OMAR].[dbo].[Covid_Deaths]
--ORDER BY 1,2 

---- US Total Cases vs Total Deaths
---- Shows the likelihood of dying if you contract covid in the US
--SELECT location, date, total_deaths, total_cases, (total_deaths/NULLIF(total_cases,0))*100 death_ratio
--FROM [AI_OMAR].[dbo].[Covid_Deaths] 
--WHERE location like 'United States'
--ORDER BY 1,2 ASC

----Looking at Total Cases vs Population of the US
--SELECT location, date, total_cases, population, (total_cases/NULLIF(population,0))*100 infection_ratio
--FROM [AI_OMAR].[dbo].[Covid_Deaths] 
--WHERE location like 'United States'
--ORDER BY 1,2 ASC


----Looking at Countries with highest Infection Rate
--SELECT location, MAX(total_cases) Highest_Infection_Count, population, MAX(total_cases/NULLIF(population,0))*100 infection_rate
--FROM [AI_OMAR].[dbo].[Covid_Deaths] 
--GROUP BY location, population
--ORDER BY infection_rate DESC

----Looking at Countries with highest Death Rate
--SELECT location, MAX(total_deaths) Total_Death_Count
--FROM [AI_OMAR].[dbo].[Covid_Deaths] 
--WHERE continent != ' '
--GROUP BY location
--ORDER BY Total_Death_Count DESC

----Looking at Countinents with highest Death Rate
--SELECT location, MAX(total_deaths) Total_Death_Count
--FROM [AI_OMAR].[dbo].[Covid_Deaths] 
--WHERE continent = ' '
--GROUP BY location
--ORDER BY Total_Death_Count DESC


-- Looking at total global covid death rate = 1.19% as of 5/17/2022. 6,225,343 total deaths
--SELECT Sum(new_deaths) as total_deaths, sum(new_cases) as total_cases, (Sum(new_deaths)/NULLIF(sum(new_cases),0))*100 death_rate
--FROM [AI_OMAR].[dbo].[Covid_Deaths] 
--WHERE continent != ' '
----GROUP BY date 
--ORDER BY death_rate DESC

----Looking at Vaccinations by location over time using Windows Function
--SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations,
--SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) as Rolling_Vaccination_Total
--FROM [AI_OMAR].[dbo].[Covid_Deaths] d
--JOIN [AI_OMAR].[dbo].[Covid_Vaccinations] v
--ON d.date = v.date and d.location = v.location
--WHERE d.continent != ' ' and d.location = 'United States'
--ORDER BY 2,3

-- Using CTE and Windows Function
--With POPvsVAC as
--(SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations,
--SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) as Rolling_Vaccination_Total
--FROM [AI_OMAR].[dbo].[Covid_Deaths] d
--JOIN [AI_OMAR].[dbo].[Covid_Vaccinations] v
--ON d.date = v.date and d.location = v.location
--WHERE d.continent != ' ' and d.location = 'United States')

--SELECT *, (Rolling_Vaccination_Total/population) * 100 as rolling_percentage
--FROM POPvsVAC

----Temp Table

--DROP TABLE if exists Percent_US_Population_Vaccinated

--CREATE TABLE Percent_US_Population_Vaccinated
--(
--Continent nvarchar(255),
--location nvarchar(255),
--date datetime,
--Population numeric,
--New_Vaccintations numeric,
--Rolling_Vaccination_Total numeric,
--)

--Insert INTO Percent_US_Population_Vaccinated
--SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations,
--SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) as Rolling_Vaccination_Total
--FROM [AI_OMAR].[dbo].[Covid_Deaths] d
--JOIN [AI_OMAR].[dbo].[Covid_Vaccinations] v
--ON d.date = v.date and d.location = v.location
--WHERE d.continent != ' ' and d.location = 'United States'

--SELECT *, (Rolling_Vaccination_Total/population) * 100 as rolling_percentage
--FROM Percent_US_Population_Vaccinated


-- --- CREATE A VIEW to use for Visualizations
CREATE VIEW Percent_US_Population_Vaccinated as
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations,
SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) as Rolling_Vaccination_Total
FROM [AI_OMAR].[dbo].[Covid_Deaths] d
JOIN [AI_OMAR].[dbo].[Covid_Vaccinations] v
ON d.date = v.date and d.location = v.location
WHERE d.continent != ' ' and d.location = 'United States'


