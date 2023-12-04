library(sf)
library(dplyr)
library(arcgis)
library(leaflet)
library(ggplot2)
library(thematic)

# open the feature server
crash_server <- arc_open("https://services.arcgis.com/UnTXoPXBYERF0OH6/arcgis/rest/services/Vehicle_Pedestrian_Incidents/FeatureServer")

# fetch individual layers
incidents <- get_layer(crash_server, 1)
hotspots <- get_layer(crash_server, 2)

# bring them into memory as sf objects
inci_sf <- arc_select(incidents)
hs_sf <- arc_select(hotspots)


# Map ---------------------------------------------------------------------

# create Hotspot labels in the dataset
hexes <- hs_sf |>
  transmute(
    classification = case_when(
      Gi_Bin == 0 ~ "Not Significant",
      Gi_Bin == 1 ~ "Hot Spot with 90% Confidence",
      Gi_Bin == 2 ~ "Hot Spot with 95% Confidence",
      Gi_Bin == 3 ~ "Hot Spot with 99% Confidence"
    )
  ) |>
  st_transform(4326)

# create labels vector to pass to leaflet
gi_labels <- c(
  "Not Significant",
  "Hot Spot with 90% Confidence",
  "Hot Spot with 95% Confidence",
  "Hot Spot with 99% Confidence"
)

pal <- colorFactor(
  palette = c("#c6c6c3", "#c8976e", "#be6448", "#af3129"),
  levels = gi_labels
)

map <- leaflet() |>
  addProviderTiles("Esri.WorldGrayCanvas") |>
  addPolygons(
    data = hexes,
    fillColor = ~pal(classification),
    color = "#c6c6c3",
    weight = 1,
    fillOpacity = 0.8
  ) |>
  addLegend(
    pal = pal,
    values = gi_labels,
    opacity = 1,
    title = "Hot Spot Classification"
  ) |>
  setView(-85.3, 35.04, 12.5)


# Plots -------------------------------------------------------------------

annual_counts <- inci_sf |>
  st_drop_geometry() |>
  mutate(year = lubridate::year(Incident_Date)) |>
  group_by(year) |>
  count() |>
  ungroup()

gg_annual <- ggplot(annual_counts, aes(year, n)) +
  geom_line() +
  geom_point() +
  labs(
    x = "Year",
    y = "Incidents"
  )

speed_counts <- inci_sf |>
  st_drop_geometry() |>
  count(Posted_Speed) |>
  filter(!is.na(Posted_Speed))

gg_speed <- ggplot(speed_counts, aes(Posted_Speed, n)) +
  geom_col() +
  labs(
    x = "Posted Speed Limit (miles per hour)",
    y = "Incidents"
  )

# Server ------------------------------------------------------------------

server <- function(input, output) {
  theme_set(theme_minimal())
  thematic_shiny()
  output$map <- renderLeaflet(map)
  output$by_speed <- renderPlot(gg_speed)
  output$incidents <- renderPlot(gg_annual)
}

# serve the app
# shinyApp(ui, server)
