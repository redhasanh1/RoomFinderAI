# Milestone 1 Problem Identification

## What unknown/wrong data is there?

- olympic_athlete_bio.csv
  - Dates in born column are incorrectly formatted, missing data, or missing
- olympic_games.csv
  - Dates in columns start_date, end_date and competition_date are missing or incorrectly formatted

<br>

## How will wrong/unknown data be handled?

- olympic_athlete_bio.csv
  - Incorrectly formatted dates will be modified to match proper format
  - Incomplete data will be estimated in a reasonable matter
  - Missing data will be kept empty
- olympic_games.csv
  - Incorrectly formatted dates and date ranges will be modified to match proper format
  - Missing data will be kept empty

<br>

## How will Paris data be organized? How does this relate to the original data file? How will you determine the duplicate athlete entries?

<br>

## How will you be able to tell if your application was working?

<br>

### Are there specific records that you can check?



# Extra:

We made a Python file that uses the import csv library and then checks how many rows are empty in all the columns, then it does a calculation of percentage of missing data to total data, Below is the analysis!


============================================================
OLYMPIC DATA FILES ANALYSIS
============================================================


============================================================
ANALYZING: olympic_athlete_bio.csv
============================================================

Total columns: 8
Columns: athlete_id, name, sex, born, height, weight, country, country_noc

Total rows: 155861

MISSING DATA:
------------------------------------------------------------
  athlete_id                         :      0 missing (  0.00%)
  name                               :      0 missing (  0.00%)
  sex                                :      0 missing (  0.00%)
  born                               :   4053 missing (  2.60%)
  height                             :  50749 missing ( 32.56%)
  weight                             :  50749 missing ( 32.56%)
  country                            :      0 missing (  0.00%)
  country_noc                        :      0 missing (  0.00%)

============================================================
ANALYSIS COMPLETE
============================================================


============================================================
ANALYZING: olympic_athlete_event_results.csv
============================================================

Total columns: 11
Columns: edition, edition_id, country_noc, sport, event, result_id, athlete, athlete_id, pos, medal, isTeamSport

Total rows: 316834

MISSING DATA:
------------------------------------------------------------
  edition                            :      0 missing (  0.00%)
  edition_id                         :      0 missing (  0.00%)
  country_noc                        :      0 missing (  0.00%)
  sport                              :      0 missing (  0.00%)
  event                              :      0 missing (  0.00%)
  result_id                          :      0 missing (  0.00%)
  athlete                            :      0 missing (  0.00%)
  athlete_id                         :      0 missing (  0.00%)
  pos                                :      0 missing (  0.00%)
  medal                              : 272147 missing ( 85.90%)
  isTeamSport                        :      0 missing (  0.00%)

============================================================
ANALYSIS COMPLETE
============================================================


============================================================
ANALYZING: olympics_country.csv
============================================================

Total columns: 2
Columns: noc, country

Total rows: 235

MISSING DATA:
------------------------------------------------------------
  noc                                :      0 missing (  0.00%)
  country                            :      0 missing (  0.00%)

============================================================
ANALYSIS COMPLETE
============================================================


============================================================
ANALYZING: olympics_games.csv
============================================================

Total columns: 11
Columns: edition, edition_id, edition_url, year, city, country_flag_url, country_noc, start_date, end_date, competition_date, isHeld

Total rows: 64

MISSING DATA:
------------------------------------------------------------
  edition                            :      0 missing (  0.00%)
  edition_id                         :      0 missing (  0.00%)
  edition_url                        :      0 missing (  0.00%)
  year                               :      0 missing (  0.00%)
  city                               :      0 missing (  0.00%)
  country_flag_url                   :      0 missing (  0.00%)
  country_noc                        :      0 missing (  0.00%)
  start_date                         :      9 missing ( 14.06%)
  end_date                           :     10 missing ( 15.62%)
  competition_date                   :      0 missing (  0.00%)
  isHeld                             :     59 missing ( 92.19%)

============================================================
ANALYSIS COMPLETE
============================================================
