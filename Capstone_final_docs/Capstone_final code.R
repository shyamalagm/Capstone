# Load data packages
library(tidyverse)
library(data.table) 
library(leaflet)
library(ggmap)
library(viridis)
library(rgdal)

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

incidents <- incidents %>% rbind(mis_incidents)
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
pincode <- pincode %>% unlist()

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

write.csv(incidents_house_price, file = 'incidents_house_price.csv')

# Reduce the number of Categories
incidents_house_price %>%
     select(Category) %>%
     count(Category) %>%
     arrange(desc(n))

Categories <- read_csv("Categories.csv")

incidents_new_categories <- left_join(incidents_house_price, Categories, by = "Category") %>%
  select(-n) %>%
  rename(New_Category = `New Category`) 

incidents_new_categories$Time <- incidents_new_categories$Time %>%
  substr(1,2) %>% as.numeric()

incidents_new_categories <- incidents_new_categories %>%
  mutate(Resolved = ifelse(Resolution == "NONE" , 0, 1))

incidents_new_categories$Resolved <- as.factor(incidents_new_categories$Resolved)
incidents_new_categories$New_Category <- as.factor(incidents_new_categories$New_Category)
incidents_new_categories$PdDistrict <- as.factor(incidents_new_categories$PdDistrict)
incidents_new_categories$DayOfWeek <- as.factor(incidents_new_categories$DayOfWeek)
incidents_new_categories$month <- as.factor(incidents_new_categories$month)
incidents_new_categories$DayOfMonth <- as.factor(incidents_new_categories$DayOfMonth)
incidents_new_categories$Time <- as.factor(incidents_new_categories$Time)

glimpse(incidents_new_categories)

# Exploratory Data Analysis 
# Density of crimes by category
zipc <- incidents_new_categories %>% 
  select(zipcode, New_Category, latitude, longitude) %>%
  count(zipcode, New_Category, latitude, longitude) %>%
  arrange(desc(n))

filt_zipc <- zipc %>% filter(n > 10) %>%
  mutate(leaflet_labels = paste0(New_Category, " (", n, ")")) %>%
  mutate(leaflet_radius = findInterval(n, c(50, 100, 200, 300, 400, 500, 600, 
                                            700, 800, 900, 1000, 2000, 5000, 10000)))
filt_zipc$New_Category <- as.factor(filt_zipc$New_Category)

col_pal <- colorFactor(palette = "magma", levels = 
                         levels(filt_zipc$New_Category))

leaflet() %>%
  setView(lng = -122.4164, lat = 37.7766, zoom = 12) %>%
  addTiles() %>%
  addCircleMarkers(filt_zipc, lng = filt_zipc$longitude, lat = filt_zipc$latitude, 
                   weight = 5, radius = filt_zipc$leaflet_radius * 1.5, fillOpacity = 0.8,
                   color = col_pal(filt_zipc$New_Category),
                   label = filt_zipc$leaflet_labels) %>%
  addLegend("topright", col_pal, values =  filt_zipc$New_Category)

# Number of crimes for each category
incidents_new_categories  %>%
  ggplot(aes(x = New_Category)) +
  geom_bar() + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  scale_y_continuous(labels=function(n){format(n, scientific = FALSE)},
                     breaks = seq(0,500000,by = 25000)) + 
  labs(x = "Categories of crime", y = "Number of crimes",
       title = "Number of crimes for each category") + 
  theme(plot.title = element_text(hjust = 0.5)) + 
  coord_flip()

incidents_new_categories %>%
  filter(New_Category %in% c("THEFT", "ARSON", "ASSAULT", "BURGLARY")) %>%
  group_by(New_Category, year) %>%
  summarise(n_crimes = n()) %>%
  ggplot(aes(x = year, y = n_crimes), fill = New_Category) + 
  geom_bar(stat = "identity") + 
  facet_grid(~ New_Category) +
  labs(x = "Years", y = "Number of crimes")

# Incidents by month and year
incidents_by_month <- incidents_new_categories %>%
  select(year, month) %>%
  count(year, month)

incidents_by_month %>%
  mutate_at(c("month"), as.factor) %>%
  mutate_at(c("year"), as.factor) %>%
  filter(n > 7000) %>%
  ggplot(aes(x = month, y = year)) +
  geom_tile(aes(fill = n)) + 
  scale_fill_gradient(low = "white", high = "darkred") +
  labs(x = "Months", y = "Years", title = "Incidents by month and year") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0),
        plot.title = element_text(hjust = 0.5)) + 
  scale_x_discrete(labels=month.name) 

#### Trend of incidents vs time
incidents_new_categories %>%
  filter(New_Category %in% c("THEFT", "ASSAULT", "ARSON", "BURGLARY", "DRUG/ALCOHOL", "VEHICLE THEFT")) %>%
  group_by(New_Category, Time) %>%
  summarise(n = n()) %>%
  ggplot(aes(x = Time, y = n)) + 
  geom_point(aes(color = New_Category)) + 
  geom_line(aes(group = New_Category, color = New_Category)) +
  labs(title = "Hourly occurence of top 6 most frequent crimes",
       x = "24 - hours", y = "Number of crimes") + 
  theme(plot.title = element_text(hjust = 0.5))

incidents_new_categories %>%
  filter(New_Category %in% c("THEFT", "ASSAULT", "ARSON", "BURGLARY", "DRUG/ALCOHOL", "VEHICLE THEFT"),
         year %in% 2003:2017) %>%
  group_by(year, New_Category, Time) %>%
  summarise(n = n()) %>%
  group_by(New_Category, Time) %>%
  ggplot(aes(x = Time, y = n, fill = New_Category)) +
  geom_bar(stat = "identity", width=1.0, color = "black") +
  facet_wrap(~year) +
  labs(title = "Hourly occurence of top 6 most frequent crimes by year",
       x = "24 - hours", y = "Number of crimes") +
  theme(plot.title = element_text(hjust = 0.5))

# Number of incidents resolved by PD district
incidents_new_categories %>%
  mutate(Solved = ifelse(Resolved == 0, "N", "Y")) %>%
  mutate_at(c("Solved"), .funs = as.factor) %>%
  ggplot(aes(x = Solved)) + 
  geom_bar(aes(color = Solved, fill = Solved)) + 
  facet_grid(~PdDistrict) +
  scale_fill_manual(values = c("DarkRed", "DarkGreen")) +
  scale_color_manual(values = c("DarkRed", "DarkGreen"))  +
  theme_bw() +
  theme(legend.position="none", plot.title = element_text(hjust = 0.5)) +
  labs(title = "Incidents resolved by each Police Department",
       x = "Resolved", y = "Number of cases")

# Number of crimes for each category
incidents_new_categories  %>%
  ggplot(aes(x = New_Category)) +
  geom_bar(aes(fill = PdDistrict), color = "black") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  scale_y_continuous(labels=function(n){format(n, scientific = FALSE)},
                     breaks = seq(0,500000,by = 25000)) + 
  labs(x = "Categories of crime", y = "Number of crimes",
       title = "Number of crimes for each category") + 
  theme(plot.title = element_text(hjust = 0.5)) + 
  coord_flip() +
  theme_bw() +
  scale_fill_brewer(palette = "Spectral")

# Number of crimes by month
incidents_new_categories %>%
  group_by(year, month) %>%
  summarise(n = n()) %>%
  ggplot(aes(x = factor(month), y = n)) + 
  geom_boxplot() + 
  geom_hline(yintercept=11994, linetype="dashed",colour='red', size = 1) +
  geom_hline(yintercept=11420, colour='red', size = 1) +  
  geom_hline(yintercept=12721., colour='red', size = 1) +
  labs(x = "Months", y = "Number of crimes",
       title = "Number of crimes by month") +
  theme_bw()

# Number of crimes by week
incidents_new_categories %>%
  group_by(month, DayOfWeek, New_Category) %>%
  summarise(n = n()) %>%
  ungroup() %>%
  group_by(New_Category) %>%
  mutate(n_median = median(n), quantile1 = quantile(n)[2], 
         quantile3 = quantile(n)[4])  %>%
  ungroup() %>%
  ggplot(aes(x = factor(DayOfWeek), y = n)) + 
  geom_boxplot() +
  geom_hline(aes(yintercept=n_median), 
             linetype="dashed",colour='red', size = 1) +
  geom_hline(aes(yintercept=quantile1), colour='red', size = 1) +  
  geom_hline(aes(yintercept=quantile3), colour='red', size = 1)  +
  labs(x = "Days of week", y = "Number of crimes",
       title = "Number of crimes by week") +
  theme_bw() +
  theme(axis.text.x=element_text(color = "black", size=8, 
                                 angle=90, hjust=1)) + 
  facet_wrap(~New_Category, scales = "free_y")

# Number of crimes by time of day
incidents_new_categories %>%
  group_by(month, DayOfWeek, Time) %>%
  summarise(n = n()) %>%
  ggplot(aes(x = factor(Time), y = n)) + 
  geom_boxplot() +
  theme_bw() +
  theme(axis.text.x  = element_text(angle=90, vjust=0.5, size=11)) +
  geom_hline(yintercept=1193, linetype="dashed",colour='red', size = 1) +
  geom_hline(yintercept=686, colour='red', size = 1) +  
  geom_hline(yintercept=1408, colour='red', size = 1) + 
  labs(x = "24 - hrs of day", y = "Number of crimes",
       title = "Number of crimes by time of day")

# Density of crime by area
precinct <- readOGR(dsn = "Current-Police-Districts")
district <- data.frame(district = precinct$district, group = seq(0.1, 10, 1)) %>%
  mutate_at(c("group"), .funs = as.factor)

sf_map <- get_map(location = "San Francisco", maptype = "roadmap", zoom = 12)
sf <- ggmap(sf_map)

plot1 <- incidents_new_categories %>%
  select(PdDistrict, latitude, longitude, New_Category) %>%
  count(PdDistrict, latitude, longitude, New_Category) %>%
  arrange(desc(n))

sf +
  geom_point(data = plot1 %>% filter (n > 20), 
             aes(x = longitude, y = latitude), color = "red",
             alpha = 0.9, size = 0.1) +  
  geom_polygon(data = left_join(fortify(precinct), district, by = "group") %>% drop_na(),
               aes(long, lat, group = group, fill = district),
               colour = "blue", alpha = 0.5) +
  scale_fill_brewer(palette = "Set3") +
  theme_bw()

# relationship between incidents and house price
library(corrplot)
incidents_by_price <- incidents_new_categories %>%
  group_by(PdDistrict, year) %>%
  mutate(median_prices = median(pricepersqft, na.rm = TRUE),
         n_crimes = n()) %>%
  select(PdDistrict, median_prices, n_crimes)%>%
  distinct()

price_vs_crimes <- incidents_by_price %>% 
  ungroup() %>% 
  select(-PdDistrict) %>%
  drop_na()
corrplot.mixed(cor(price_vs_crimes), lower.col = "black", upper = "color")


# Machine Learning
set.seed(1234)
library(caTools)
library(caret)
library(ROCR)
library(Metrics)

split <- sample.split(incidents_new_categories, SplitRatio = 0.7)
training <- subset(incidents_new_categories, split == 'TRUE')
testing <- subset(incidents_new_categories, split == 'FALSE')

model <- glm(Resolved ~ New_Category + PdDistrict +  month + DayOfMonth + Time,
             training, family = "binomial")
summary(model)

exp(coef(model))

pred <- predict(model, newdata = testing, type = "response")
pred <- ifelse(pred > 0.5, 1, 0)
confusionMatrix(testing$Resolved, pred)

pr <- prediction(pred, testing$Resolved)
perf <- performance(pr, measure = "tpr", x.measure = "fpr")
plot(perf)

auc <- performance(pr, measure = "auc")
auc <- auc@y.values[[1]]
auc




