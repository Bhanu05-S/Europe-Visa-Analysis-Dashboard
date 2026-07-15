/* ============================================================
   EUROPE VISA APPLICATIONS - SQL SCHEMA & ANALYTICAL QUERIES
   Reproduces the Power BI report "Europe_Visa.pbix"
   (DAX measures translated to standard SQL)
   Tested against SQLite; portable to Postgres/MySQL/SQL Server
   with minor syntax tweaks (noted where relevant).
   ============================================================ */

/* ---------- 1. SCHEMA ---------- */

DROP TABLE IF EXISTS europe_visa_data;

CREATE TABLE europe_visa_data (
    Year               INTEGER,
    Quarter            TEXT,          -- e.g. '2019 Q4'
    Country            TEXT,          -- Sweden, Spain, Netherlands, ...
    "Visa Type"        TEXT,          -- Work Permit, Business Visa, Visa Stamping, Dependent Visa, ...
    Nationality        TEXT,
    Region             TEXT,
    Outcome            TEXT,          -- Issued / Refused
    Applications       INTEGER,
    "Approval Status"  TEXT,          -- Approved / Refused
    Period             TEXT,          -- Pre-COVID (2015-2019), COVID, Recovery, etc.
    "Is Work Related"  TEXT,
    "Quarter Number"   TEXT,          -- Q1..Q4
    "Country Flag"     TEXT
);

CREATE INDEX idx_country     ON europe_visa_data(Country);
CREATE INDEX idx_year        ON europe_visa_data(Year);
CREATE INDEX idx_visa_type   ON europe_visa_data("Visa Type");
CREATE INDEX idx_nationality ON europe_visa_data(Nationality);
CREATE INDEX idx_outcome     ON europe_visa_data(Outcome);

/* Data load: see europe_visa_dump.sql for full INSERT statements
   (481,900 rows) generated from the .pbix data model. */


/* ============================================================
   2. DAX MEASURES -> SQL  (as reusable views)
   ============================================================ */

-- Total Applications = SUM(Applications)
CREATE VIEW v_total_applications AS
SELECT SUM(Applications) AS total_applications
FROM europe_visa_data;

-- Total Approved = SUM(Applications) WHERE Outcome = 'Issued'
CREATE VIEW v_total_approved AS
SELECT SUM(Applications) AS total_approved
FROM europe_visa_data
WHERE Outcome = 'Issued';

-- Total Refused = SUM(Applications) WHERE Outcome = 'Refused'
CREATE VIEW v_total_refused AS
SELECT SUM(Applications) AS total_refused
FROM europe_visa_data
WHERE Outcome = 'Refused';

-- Approval Rate % = Total Approved / Total Applications * 100
CREATE VIEW v_approval_rate AS
SELECT
    ROUND(100.0 * SUM(CASE WHEN Outcome = 'Issued'  THEN Applications ELSE 0 END)
          / NULLIF(SUM(Applications), 0), 2) AS approval_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN Outcome = 'Refused' THEN Applications ELSE 0 END)
          / NULLIF(SUM(Applications), 0), 2) AS refusal_rate_pct
FROM europe_visa_data;

-- Country-specific totals (Sweden / Spain / Netherlands Total)
CREATE VIEW v_country_totals AS
SELECT Country, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Country
ORDER BY applications DESC;

-- Visa-type totals (Work Permit / Business Visa / Visa Stamping / Dependent Visa)
CREATE VIEW v_visa_type_totals AS
SELECT "Visa Type", SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY "Visa Type"
ORDER BY applications DESC;

-- YoY Growth % = (This Year - Prior Year) / Prior Year * 100
CREATE VIEW v_yoy_growth AS
WITH yearly AS (
    SELECT Year, SUM(Applications) AS applications
    FROM europe_visa_data
    GROUP BY Year
)
SELECT
    Year,
    applications,
    LAG(applications) OVER (ORDER BY Year) AS prior_year_applications,
    ROUND(100.0 * (applications - LAG(applications) OVER (ORDER BY Year))
          / NULLIF(LAG(applications) OVER (ORDER BY Year), 0), 2) AS yoy_growth_pct
FROM yearly
ORDER BY Year;

-- COVID Recovery Rate % = Applications(2024) / Applications(2019) * 100
CREATE VIEW v_covid_recovery_rate AS
SELECT
    ROUND(100.0 *
        (SELECT SUM(Applications) FROM europe_visa_data WHERE Year = 2024) /
        NULLIF((SELECT SUM(Applications) FROM europe_visa_data WHERE Year = 2019), 0)
    , 2) AS covid_recovery_rate_pct;


/* ============================================================
   3. PAGE-BY-PAGE QUERIES
   ============================================================ */

/* ---- PAGE 1: OVERVIEW ---- */

-- KPI cards: Total Applications, Total Approved, Total Refused, Approval Rate %, Refusal Rate %
SELECT
    SUM(Applications) AS total_applications,
    SUM(CASE WHEN Outcome='Issued' THEN Applications ELSE 0 END) AS total_approved,
    SUM(CASE WHEN Outcome='Refused' THEN Applications ELSE 0 END) AS total_refused,
    ROUND(100.0*SUM(CASE WHEN Outcome='Issued' THEN Applications ELSE 0 END)/SUM(Applications),2) AS approval_rate_pct,
    ROUND(100.0*SUM(CASE WHEN Outcome='Refused' THEN Applications ELSE 0 END)/SUM(Applications),2) AS refusal_rate_pct
FROM europe_visa_data;

-- Donut chart: Applications by Outcome
SELECT Outcome, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Outcome;

-- Donut chart: Applications by Visa Type
SELECT "Visa Type", SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY "Visa Type"
ORDER BY applications DESC;

-- Clustered column chart: Applications by Country
SELECT Country, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Country
ORDER BY applications DESC;

-- Area chart: Applications trend over time (Year/Quarter)
SELECT Year, "Quarter Number", SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Year, "Quarter Number"
ORDER BY Year, "Quarter Number";


/* ---- PAGE 2: COUNTRY ANALYSIS ---- */

-- Clustered column: Applications by Country and Outcome
SELECT Country, Outcome, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Country, Outcome
ORDER BY Country, Outcome;

-- Clustered bar: Applications by Country and Visa Type
SELECT Country, "Visa Type", SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Country, "Visa Type"
ORDER BY Country, applications DESC;

-- Line chart: Applications trend per Country over Year
SELECT Country, Year, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Country, Year
ORDER BY Country, Year;

-- 100% stacked bar: Approval/Refusal share per Country
SELECT
    Country,
    SUM(CASE WHEN Outcome='Issued' THEN Applications ELSE 0 END) AS approved,
    SUM(CASE WHEN Outcome='Refused' THEN Applications ELSE 0 END) AS refused,
    ROUND(100.0*SUM(CASE WHEN Outcome='Issued' THEN Applications ELSE 0 END)/SUM(Applications),2) AS approval_rate_pct
FROM europe_visa_data
GROUP BY Country
ORDER BY Country;


/* ---- PAGE 3: VISA TYPE DEEP DIVE ---- */

-- KPI cards: totals per visa type (Work Permit, Business Visa, Visa Stamping, Dependent Visa)
SELECT "Visa Type", SUM(Applications) AS applications
FROM europe_visa_data
WHERE "Visa Type" IN ('Work Permit','Business Visa','Visa Stamping','Dependent Visa')
GROUP BY "Visa Type";

-- Clustered bar: Visa Type by Country
SELECT "Visa Type", Country, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY "Visa Type", Country
ORDER BY "Visa Type", applications DESC;

-- Line chart: Visa Type trend over Year
SELECT "Visa Type", Year, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY "Visa Type", Year
ORDER BY "Visa Type", Year;

-- Bar chart: Applications by Period (Pre-COVID / COVID / Recovery, etc.) and Visa Type
SELECT Period, "Visa Type", SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Period, "Visa Type"
ORDER BY Period, applications DESC;

-- 100% stacked bar: Approval rate by Visa Type
SELECT
    "Visa Type",
    SUM(CASE WHEN Outcome='Issued' THEN Applications ELSE 0 END) AS approved,
    SUM(CASE WHEN Outcome='Refused' THEN Applications ELSE 0 END) AS refused,
    ROUND(100.0*SUM(CASE WHEN Outcome='Issued' THEN Applications ELSE 0 END)/SUM(Applications),2) AS approval_rate_pct
FROM europe_visa_data
GROUP BY "Visa Type"
ORDER BY "Visa Type";


/* ---- PAGE 4: NATIONALITY & REGION ---- */

-- Clustered bar: Applications by Region
SELECT Region, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Region
ORDER BY applications DESC;

-- Map visual: Applications by Country (with coordinates resolved client-side/by BI tool)
SELECT Country, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Country
ORDER BY applications DESC;

-- Bar chart: Applications by Nationality
SELECT Nationality, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Nationality
ORDER BY applications DESC;

-- Table: Top N Nationalities (parameterize N; default 10, matches "Top N Nationalitites" slicer)
SELECT Nationality, SUM(Applications) AS applications
FROM europe_visa_data
GROUP BY Nationality
ORDER BY applications DESC
LIMIT 10;   -- change LIMIT to match the slicer's selected N


/* ============================================================
   4. NOTES ON PORTABILITY
   ------------------------------------------------------------
   - This script uses SQLite syntax (LIMIT, double-quoted
     identifiers, NULLIF).
   - Postgres: identical syntax works as-is.
   - MySQL: replace double-quoted identifiers with backticks
     (`Visa Type` instead of "Visa Type").
   - SQL Server: replace LIMIT n with TOP n (or OFFSET/FETCH),
     and double-quoted identifiers with brackets [Visa Type].
   ============================================================ */
