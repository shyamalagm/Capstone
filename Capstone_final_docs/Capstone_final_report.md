---
title: "Foundations of Data Science - Capstone Final Report"
author: "Shyamala Gurumurthy"
date: "March 30, 2018"
output: 
  html_document: 
    highlight: tango
    keep_md: yes
    theme: cosmo
    df_print: paged
---


### San Francisco Police Incidents

The city of San Francisco is not only known as a commercial and financial center of Northen California, but is also earning a growing reputation for having one of the highest crime rates in the country. The San Francisco Police Department (SFPD) is the city police department of San Francisco that serves an estimated population of 1.2 million. The SFPD has been frequently met with criticism, due to the large number of cases that remain unsolved every year. For this reason, SFPD is determined to build trust, engage with the San Francisco community, and drive positive outcomes in public safety. In an effort to be as transparent as possible with information about the department and its operation, SFPD has shared [various data sets](https://data.sfgov.org/browse?Department-Metrics_Publishing-Department=Police%20Department). The [Police Department incidents](https://data.sfgov.org/Public-Safety/Police-Department-Incidents/tmnf-yvry) data is analyzed in this project. Of interest is also the effect of crimes rates on the real estate prices. To aid in this inference a [secondary dataset](https://www.zillow.com/research/data/) consisting of house prices was downloaded from [Zillow](https://www.zillow.com/). Both the datasets were available as CSV files.

The [Police Department incidents](https://data.sfgov.org/Public-Safety/Police-Department-Incidents/tmnf-yvry) is imported into R and named as `incidents`. It is derived from the SFPD Crime Incident Reporting System  and consists of a list of crime entries from 01/01/2003 up until 12/31/2017. It has around 2.18 million entries of incidents. There are 13 features in this dataset which are as follows.

1. IncidntNum 
2. Category
3. Descript 
4. DayOfWeek
5. Date
6. Time
7. PdDistrict
8. Resolution
9. Address
10. X
11. Y
12. Location
13. PdId

The columns `IncidentNum` and `PdID` are unique identification numbers for each incident occured. The column `Category` consists of 39 different categories of incidents committed all over San Francisco. Detailed description for all the incidents is provided in the column `Descript`. Further details such as the date, day and time when a particular incident occured are given in columns `Date`, `DayOfWeek` and `Time` respectively. The police district that handled the incident is in `PdDistrict` and the resolution that was provided by them is in `Resolution`. There are 10 distinct police districts accross San Francisco. The address where the incident occured with exact co-ordinates for longitude and latitude are given in `Address`, `X` and `Y` respectively. `Location` is a set of co-ordinates `(Y, X)`. A glimpse of the dataset is given below.


```
## Observations: 2,175,688
## Variables: 13
## $ IncidntNum <int> 150060275, 150098210, 150098210, 150098210, 1500982...
## $ Category   <chr> "NON-CRIMINAL", "ROBBERY", "ASSAULT", "SECONDARY CO...
## $ Descript   <chr> "LOST PROPERTY", "ROBBERY, BODILY FORCE", "AGGRAVAT...
## $ DayOfWeek  <chr> "Monday", "Sunday", "Sunday", "Sunday", "Tuesday", ...
## $ Date       <chr> "01/19/2015", "02/01/2015", "02/01/2015", "02/01/20...
## $ Time       <time> 14:00:00, 15:45:00, 15:45:00, 15:45:00, 19:00:00, ...
## $ PdDistrict <chr> "MISSION", "TENDERLOIN", "TENDERLOIN", "TENDERLOIN"...
## $ Resolution <chr> "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NO...
## $ Address    <chr> "18TH ST / VALENCIA ST", "300 Block of LEAVENWORTH ...
## $ X          <dbl> -122.4216, -122.4144, -122.4144, -122.4144, -122.43...
## $ Y          <dbl> 37.76170, 37.78419, 37.78419, 37.78419, 37.80047, 3...
## $ Location   <chr> "(37.7617007179518, -122.42158168137)", "(37.784190...
## $ PdId       <dbl> 1.500603e+13, 1.500982e+13, 1.500982e+13, 1.500982e...
```

The secondary dataset [Zillow](https://www.zillow.com/research/data/) is also imported into R and named as `house_prices`. It has ~15000 records of median price per square feet for all the regions in US. It has features that include RegionID, RegionName, City, State, Metro, CountyName, SizeRank and 261 columns of price per sqft from 1996 to 2017 for all 12 months. From this dataset, we would require the median house prices per sqft data for only San Francisco. 


### Problem Statements

The two main goals of this capstone are,

1.  To predict if an incident would be resolved by a Police department, given its category.

2. Infer if crime rates affect property prices in San Francisco. That is, to see if the areas that have low crime rates enjoy higher property values.

### Data Wrangling

The data wrangling method will involve identifying the variables that have an effect on the categories of crime. This includes creating new variables such as Year, Month, Date, etc. and deleting varibles that have no effect on the analysis such as Incident Number, Pdid, etc. It also involves missing/outlier values(if any!) and replacing/deleting them appropriately. The Zillow dataset must be combined with the SFPD dataset to yield the property price corresponding to each crime location. A more detailed explanation for the same follows.



#### Data Wrangling - Incidents File

  1. The dataset is examined for dimensions, columns names, structure and summary statistics.
  2. The `IncidntNum` and `PdId` columns are removed as they contain unique id for incidents registered and hence will not be of much use. All other columns are retained.
  3. The `Date` column is separated into `Month`, `DayofMonth` and `Year` columns. These columns are converted to numeric data type.
  4. Dealing with missing observations
  
    (i). The dataframe is checked for missing values. It is observed that it has only 1 row with a missing `PdDistrict` value. This observation is stored in a dataframe called `mis_incidents`. The remaining complete cases are stored in `incidents` dataframe.
   (ii). The missing value is now imputed as follows. It is noticed that the Address column in incidents dataframe is not unique. Therefore, the Address from `mis_incidents` is matched to Address in `incidents` dataframe. Then, the corresponding `PDdistrict` for that address is filled into the missing value. It is found that the address `100 Block of VELASCO AV` corresponds to the `Ingleside` police district. This observation is then added back to the `incidents` dataframe.
   
   5. Two columns `X`, `Y` is respectively renamed to the more descriptive `longitude` and `latitude`.
   
#### Data Wrangling - House Prices File
   
  1. This dataset is also examined for dimensions, columns names, structure and summary statistics.
  2. A new dataframe called `sf_house_price` is created by filtering the house prices only for San Francisco city.
  3. The columns `RegionID`, `State`, `Metro`, `CountyName` and `SizeRank` are removed as only the columns `City`, `RegionName` and the price per sqft for all the months and years is required.
  4. It is noticed that data is in wide format, where 261 of the 263 columns represent the price per sqft for a given month and year. This is converted into a long format data with just 4 columns namely `RegionName, City, yearmonth and pricepersqft`. The `yearmonth` column is later separated into 2 columns, `year` and `month`.
  5. The column `RegionName` is also renamed to a more descriptive name `zipcode`.

#### Merge Incidents and House prices file 

To combine the `incidents` and `sf_house_price` dataframes, I have loaded a new library called `zipcode`. The dataframe `zipcode` in this library will help me in obtaining corresponding zipcodes for the `latitude` and `longitude` columns in `incidents` dataset. This new column is later used as a key to join the `incidents` and `sf_house_prices` dataframes.
  
  1. As mentioned above, the `zipcode` dataset is used to merge the 2 dataframes. A new dataframe called `zipcode_ca` is created by filtering the zipcodes for California state.
  2. A function called `get_zipcodes` is created. This function will take latitude and longitude as its input values, match it with the latitude and longitude in the zipcode_ca file and then give the corresponding zipcode as an output. There is always a possibility that the input values do not match exactly with the one in the zipcode_ca file. For this reason, we calculate the difference between the  2 latitudes and  2 longitudes, and then find the Euclidean distance between them. The zipcode for the value which has the minimum distance is then taken as the match.
  3. As mentioned earlier, the `incidents` dataframe has about ~2.18 million records in it. Also, the columns `Address`, `longitude` and `latitude` have a number of values which are repeated. Hence, we create a temporary dataframe called `incidents_loc`, which would contain only distinct values of the above mentioned columns and reduce the processing time considerably. This file now has only ~77000 records. 
  4. The function `get_zipcodes` is applied to the `incidents_loc` dataframe and a new column `zipcodes` is added to it.
  5. The updated `incidents_loc` dataframe is now joined with the `incidents` dataframe to get a column `zipcode` for all the ~2.18 million records of latitude and longitude.
  6. This `zipcode` column is used to join the `incidents` dataframe with the `sf_house_price` dataframe. The resulting `incidents_house_price` dataframe now contains the house prices corresponding to each incident location by year and month.

#### Data Wrangling - Incidents_house_price file

Before proceeding to exploratory data analysis, some changes are made to the `incidents_house_price` dataframe. The column `Category` as mentioned before, has 39 distinct crime categories as shown below. 

<div data-pagedtable="false">
  <script data-pagedtable-source type="application/json">
{"columns":[{"label":["Category"],"name":[1],"type":["chr"],"align":["left"]}],"data":[{"1":"NON-CRIMINAL"},{"1":"ROBBERY"},{"1":"ASSAULT"},{"1":"SECONDARY CODES"},{"1":"VANDALISM"},{"1":"BURGLARY"},{"1":"LARCENY/THEFT"},{"1":"DRUG/NARCOTIC"},{"1":"WARRANTS"},{"1":"VEHICLE THEFT"},{"1":"OTHER OFFENSES"},{"1":"WEAPON LAWS"},{"1":"ARSON"},{"1":"MISSING PERSON"},{"1":"DRIVING UNDER THE INFLUENCE"},{"1":"SUSPICIOUS OCC"},{"1":"RECOVERED VEHICLE"},{"1":"DRUNKENNESS"},{"1":"TRESPASS"},{"1":"FRAUD"},{"1":"DISORDERLY CONDUCT"},{"1":"SEX OFFENSES, FORCIBLE"},{"1":"FORGERY/COUNTERFEITING"},{"1":"KIDNAPPING"},{"1":"EMBEZZLEMENT"},{"1":"STOLEN PROPERTY"},{"1":"LIQUOR LAWS"},{"1":"FAMILY OFFENSES"},{"1":"LOITERING"},{"1":"BAD CHECKS"},{"1":"TREA"},{"1":"GAMBLING"},{"1":"RUNAWAY"},{"1":"BRIBERY"},{"1":"PROSTITUTION"},{"1":"PORNOGRAPHY/OBSCENE MAT"},{"1":"SEX OFFENSES, NON FORCIBLE"},{"1":"SUICIDE"},{"1":"EXTORTION"}],"options":{"columns":{"min":{},"max":[10]},"rows":{"min":[10],"max":[10]},"pages":{}}}
  </script>
</div>

To simplify the analysis, categories with common crime types are combined together. This resulted in a reduction of categories from 39 to 15. The resulting new categories are stored in a dataframe called `Categories`. The table below shows the list of old categories along with new, common group name.

<div data-pagedtable="false">
  <script data-pagedtable-source type="application/json">
{"columns":[{"label":["Category"],"name":[1],"type":["chr"],"align":["left"]},{"label":["New Category"],"name":[2],"type":["chr"],"align":["left"]}],"data":[{"1":"LARCENY/THEFT","2":"THEFT"},{"1":"EMBEZZLEMENT","2":"THEFT"},{"1":"OTHER OFFENSES","2":"OTHER OFFENSES"},{"1":"FAMILY OFFENSES","2":"OTHER OFFENSES"},{"1":"SECONDARY CODES","2":"OTHER OFFENSES"},{"1":"SUSPICIOUS OCC","2":"OTHER OFFENSES"},{"1":"NON-CRIMINAL","2":"NON-CRIMINAL"},{"1":"SUICIDE","2":"NON-CRIMINAL"},{"1":"GAMBLING","2":"NON-CRIMINAL"},{"1":"ASSAULT","2":"ASSAULT"},{"1":"VEHICLE THEFT","2":"VEHICLE THEFT"},{"1":"RECOVERED VEHICLE","2":"VEHICLE THEFT"},{"1":"DRUG/NARCOTIC","2":"DRUG/ALCOHOL"},{"1":"DRIVING UNDER THE INFLUENCE","2":"DRUG/ALCOHOL"},{"1":"DRUNKENNESS","2":"DRUG/ALCOHOL"},{"1":"LIQUOR LAWS","2":"DRUG/ALCOHOL"},{"1":"VANDALISM","2":"ARSON"},{"1":"ARSON","2":"ARSON"},{"1":"TRESPASS","2":"ARSON"},{"1":"STOLEN PROPERTY","2":"ARSON"},{"1":"WARRANTS","2":"WARRANTS"},{"1":"BURGLARY","2":"BURGLARY"},{"1":"ROBBERY","2":"BURGLARY"},{"1":"MISSING PERSON","2":"MISSING PERSON"},{"1":"RUNAWAY","2":"MISSING PERSON"},{"1":"KIDNAPPING","2":"MISSING PERSON"},{"1":"FRAUD","2":"FRAUD"},{"1":"FORGERY/COUNTERFEITING","2":"FRAUD"},{"1":"BAD CHECKS","2":"FRAUD"},{"1":"PROSTITUTION","2":"SEXUAL OFFENSES"},{"1":"SEX OFFENSES, FORCIBLE","2":"SEXUAL OFFENSES"},{"1":"SEX OFFENSES, NON FORCIBLE","2":"SEXUAL OFFENSES"},{"1":"PORNOGRAPHY/OBSCENE MAT","2":"SEXUAL OFFENSES"},{"1":"WEAPON LAWS","2":"WEAPON"},{"1":"TREA","2":"WEAPON"},{"1":"DISORDERLY CONDUCT","2":"DISORDERLY CONDUCT"},{"1":"LOITERING","2":"DISORDERLY CONDUCT"},{"1":"EXTORTION","2":"EXTORTION"},{"1":"BRIBERY","2":"EXTORTION"}],"options":{"columns":{"min":{},"max":[10]},"rows":{"min":[10],"max":[10]},"pages":{}}}
  </script>
</div>

The `Categories` and `incidents_house_price` are joined to create a new dataframe `incidents_new_categories` which now has a column for new category name. This is the file used in the rest of the analysis that follows.
