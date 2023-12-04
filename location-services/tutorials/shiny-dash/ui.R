library(shiny)
library(bslib)
library(bsicons)

stats <- layout_columns(
  value_box(
    "Number of Incidents",
    "681",
    showcase = bs_icon("person")
  ),
  value_box(
    "Total Fatalities",
    "40",
    showcase = bs_icon("heartbreak")
  ),
  value_box(
    "Involved Medical Transport",
    "381",
    showcase = bs_icon("heart-pulse")
  ),
  value_box(
    "Involved Drugs or Alcohol",
    "36",
    showcase = bs_icon("capsule")
  ),
  col_widths = c(6, 6)
  # col_widths = 12
)

plots <- layout_columns(
  card(
    card_header("Vehicle-Pedestrian Incidents by Year"),
    plotOutput("incidents")
  ),
  card(
    card_header("Vehicle-Pedestrian Incidents by Posted Speed Limit"),
    plotOutput("by_speed")
  ),
  col_widths = 12
)

plot_tab <- navset_card_tab(
  title = "Plots",
  nav_panel(
    "By year",
    card_title("Vehicle-Pedestrian Incidents by Year"),
    plotOutput("incidents")
  ),
  nav_panel(
    "By speed",
    card_title("Vehicle Pedestrian Incidents by Posted Speed Limit"),
    card(card_body(plotOutput("by_speed")))
  )
)

ui <- page_fillable(
  theme = bs_theme(bootswatch = "darkly"),
  card_title("Automobile Crashes"),
  layout_columns(
    card(
      leafletOutput("map")
    ),
    layout_columns(
      stats,
      plot_tab,
      col_widths = 12
    ),
    col_widths = c(8,4)
  )
)
