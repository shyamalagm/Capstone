---
title: "Capstone Project Proposals - I "
author: "Shyamala Gurumurthy"
date: "15 January, 2018"
output: 
  html_document: 
    keep_md: yes
    theme: yeti
---

## [Nonimmigrant Visa Statistics](https://travel.state.gov/content/travel/en/legal/visa-law0/visa-statistics/nonimmigrant-visa-statistics.html)

Data for non-immigrant visa issuances (NIV) between the years 1997 - 2016 are provided in [Excel format](https://travel.state.gov/content/dam/visas/Statistics/Non-Immigrant-Statistics/NIVDetailTables/FYs97-16_NIVDetailTable.xls). 

Each sheet in the Excel file contains NIV data corresponding to a particular year. Observations represent countries while the features are visa types.

### Objective

Possible goals for predicting might be,

1. Total number of NIVs that would have been (or will be) issued to a given country for a given year.
2. Number of NIVs *of a given type* that would have been (or will be) issued to a given country for a given year.


### Data cleaning

Data pre-processing would involve the following,

1. Collating data from all sheets into one file
2. Tidying and cleaning data (removing headings, empty lines, adding useful columns etc)
3. Handling missing values and outliers

### Exploratory data analysis

EDA would consist of plots showing number of NIVs for each country by year and visa type. 

### Model building

Depending on the objective, this would typically involve some type of multi-variate regression. Metrics for assessing accuracy of predictions must also be determined.



