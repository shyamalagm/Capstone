library(tidyverse)
library(leaflet)
library(ggmap)

Categories <- read_csv("Categories.csv")
incidents_house_price <- read_csv("incidents_house_price.csv")

incidents_new_categories <- left_join(incidents_house_price, Categories, by = "Category") %>%
  select(-n) %>%
  rename(New_Category = `New Category`) 

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



sf_map <- get_map(location = "San Francisco", maptype = "roadmap", zoom = 12)
sf <- ggmap(sf_map)

plot1 <- incidents_new_categories %>%
  filter(New_Category %in% c("THEFT", "ARSON", "SEXUAL OFFENSES", "WEAPON")) %>%
  select(zipcode, New_Category, latitude, longitude) %>%
  count(zipcode, New_Category, latitude, longitude) %>%
  arrange(desc(n))

sf +
  geom_point(data = plot1 %>% filter (n > 20), 
             aes(x = longitude, y = latitude), color = "red",
             alpha = 0.9, size = 0.1) +
  labs(title = "Spatial distribution of crimes" , x = "Longitude", 
       y = "Latitude") +
  theme(plot.title = element_text(hjust = 0.5)) + 
  facet_grid(~ New_Category)


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



incidents_by_day <- incidents_new_categories %>%
  select(DayOfWeek, New_Category) %>%
  count(DayOfWeek) 

pie <- incidents_by_day %>% 
  ggplot(aes(x = factor(1), y = n, fill = DayOfWeek)) + 
  geom_bar(width = 1,stat="identity", color = "black") + 
  guides(fill=guide_legend(override.aes=list(colour=NA))) +
  theme(axis.ticks=element_blank(),  
        axis.title=element_blank(),  
        axis.text.y=element_blank()) 

y.breaks <- cumsum(incidents_by_day$n) - incidents_by_day$n/2

pie + 
  labs(title = "Variation in crimes by day")
  theme(axis.text.x=element_text(color='black'), plot.title = element_text(hjust = 0.5)) +
  scale_y_continuous(breaks=y.breaks, labels=incidents_by_day$DayOfWeek) + 
  geom_text(aes(y=y.breaks, label = n), size=3)

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

resolution <- incidents_new_categories %>%
  select(New_Category, PdDistrict,Resolution) %>%
  mutate(Resolved = ifelse(Resolution == "NONE" , 0, 1))

resolution %>%
  mutate(Resolved = ifelse(Resolved == 0, "N", "Y")) %>%
  mutate_at(c("Resolved"), .funs = as.factor) %>%
  ggplot(aes(x = Resolved)) + 
  geom_bar(aes(color = Resolved, fill = Resolved)) + 
  facet_grid(~PdDistrict) +
  scale_fill_manual(values = c("DarkRed", "DarkGreen")) +
  scale_color_manual(values = c("DarkRed", "DarkGreen"))  +
  theme_bw() +
  theme(legend.position="none", plot.title = element_text(hjust = 0.5)) +
  labs(title = "Incidents resolved by each Police Department",
       x = "Resolved", y = "Number of cases")

incidents_new_categories$Time <- incidents_new_categories$Time %>%
  substr(1,2) %>% as.numeric()

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

incidents_by_price <- incidents_new_categories %>%
  group_by(PdDistrict) %>%
  mutate(median_prices = median(pricepersqft, na.rm = TRUE),
         n_crimes = n()) %>%
  select(PdDistrict, median_prices, n_crimes)%>%
  distinct()

incidents_by_price %>% 
  ggplot(aes(x = PdDistrict)) + 
  geom_point(aes(y = n_crimes, color = "Crimes"), size = 2) +
  geom_line(aes(y = n_crimes, group = 1, color = "Crimes"), size = 1) +
  geom_point(aes(y = median_prices * 500, color = "Property prices"), size = 2) +
  geom_line(aes(y = median_prices * 500, group = 1, color = "Property prices"), size = 1) +
  scale_y_continuous(sec.axis = sec_axis(~. *0.002, name = "Property Prices [per sqft]"),
                     labels=function(n){format(n, scientific = FALSE)},
                     breaks = seq(0,500000,by = 25000)) + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1),
        plot.title = element_text(hjust = 0.5)) + 
  scale_colour_manual(values = c("red", "blue")) + 
  labs(title = "Crimes Vs Property prices", y = "Number of Crimes", 
       x = "San Francisco Areas", colour = "Parameter")

