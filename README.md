# R-ArcGIS Bridge Documentation

This repository contains the public facing source of https://developers.arcgis.com/r-bridge.

We use this repository to build out the internal docs infrastructure. This way, you, the community can contribute. 

## Building the docs

To build **API Reference** run `dev/generate-api-ref.R`. This will clone all of the repositories and build the documentation using pkgdown and some other magic. 

## Building the articles

To build all other documentation run `dev/generate-docs.R`. This will render `.qmd` files using R Markdown and perform syntax hilighting with downlit. 