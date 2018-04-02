# Load data packages
library(tidyverse)
library(data.table) 
library(leaflet)
library(ggmap)

# Import data sets
incidents <- read_csv("C:/Users/User/Desktop/Capstone/data/Police_Cases/Police_Department_Incidents.csv")
house_prices <- read_csv("C:/Users/User/Desktop/Capstone/data/Police_Cases/Zip_MedianValuePerSqft_AllHomes.csv")

# Convert datasets to a tbl
tbl_df(incidents)
tbl_df(house_prices)

# Data Wrangling - incidents
dim(incidents)  
names(incidents)  
glimpse(incidents) 
summary(incidents)

# Remove the unnecessary columns
incidents<- incidents %>% select(-IncidntNum, -PdId)
names(incidents)

# Seperate the Date column into 3 columns(Month, DayofMonth, Year) and convert them into numeric
incidents <- separate(incidents, Date, c("Month", "DayOfMonth", "Year"))
incidents <- incidents %>% mutate_at(vars(DayOfMonth, Year, Month), funs(as.numeric))
glimpse(incidents)

# Check for missing values and save them to separate dataframe
colSums(is.na(incidents))
mis_incidents  <- incidents[!complete.cases(incidents),]
incidents      <- incidents[complete.cases(incidents),]

# Fill in missing information
pd_district <- incidents %>%
  filter(mis_incidents$Address == Address) %>%
  select(PdDistrict) %>%
  distinct() %>%
  pull()

mis_incidents$PdDistrict <- pd_district

incidents %<>% rbind(mis_incidents)
colSums(is.na(incidents))

# Clean up the column names
setnames(incidents, "X", "longitude")
setnames(incidents, "Y", "latitude")
colnames(incidents)

# Data Wrangling - house_prices 
dim(house_prices)  
names(house_prices)  
glimpse(house_prices) 
summary(house_prices)

# Filter property prices for San Francisco
sf_house_price <- house_prices %>% 
  filter(City == "San Francisco") %>% 
  select (-(State:SizeRank))

# Reduce the number of variables 
sf_house_price <- gather(sf_house_price, yearmonth, pricepersqft, -(RegionID : City)) %>%
  select(- RegionID)
sf_house_price <- separate(sf_house_price, yearmonth, c("year", "month")) %>%
  arrange(RegionName)

# Clean up the column names
setnames(sf_house_price, "RegionName", "zipcode")
sf_house_price <- sf_house_price %>% 
  mutate_at(vars(zipcode, year, month), funs(as.numeric))

# Data Wrangle - zipcode
library(zipcode)
data(zipcode)

zipcode_ca <- zipcode %>% filter(state == "CA")

# Merge incidents and zipcode #
get_zipcode <- function(lat, lon){
  pincode <- zipcode_ca %>%
    mutate(lat_diff = latitude - lat,
           lon_diff = longitude - lon,
           dist = sqrt(lat_diff**2 + lon_diff**2)) %>% 
    filter(dist == min(dist)) %>% 
    select(zip) %>% 
    pull() %>%
    as.numeric()
  
  return(pincode)
}

incidents_loc <- incidents %>%
  select(Address, longitude, latitude) %>%
  distinct()

library(pbapply)
pincode <- pblapply(1:nrow(incidents_loc),
                    function(x) get_zipcode(incidents_loc$latitude[x],
                                            incidents_loc$longitude[x]))
pincode %<>% unlist()

pincode %>%
  as.data.frame(col.names = "pincode") %>%
  write_csv(path = "pincode.csv")

# pincode <- read_csv("pincode.csv") %>%
# as.list() %>%
# unlist(use.names = FALSE)

incidents_loc <- incidents_loc %>%
  mutate(zipcode = pincode)

incidents_zip <- left_join(incidents, incidents_loc, 
                           by = c("Address", "latitude", "longitude")) %>%
  rename(month = Month, year = Year)

incidents_house_price <- left_join(incidents_zip, sf_house_price, 
                                   by = c("zipcode", "year", "month")) %>% 
  select(-City)

# Reduce the number of Categories

x <- incidents_house_price %>%
     select(Category) %>%
     count(Category) %>%
     arrange(desc(n))

Categories <- read_csv("Categories.csv")

incidents_new_categories <- left_join(incidents_house_price, Categories, by = "Category") %>%
  select(-n) %>%
  rename(New_Category = `New Category`) 