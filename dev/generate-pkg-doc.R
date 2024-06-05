pkgs <- c("arcgisutils", "arcgislayers", "arcgisplaces", "arcgisgeocode")

# R Version >= 4.4
#
# Package Dependencies:
# - pandoc
# - rvest
# - xml2

html_to_md <- function(reference) {
  pandoc::pandoc_convert(
    text = reference,
    from = "html",
    to = "gfm",
    args = "--wrap=none"
  )
}

pkg_to_md <- function(pkg) {
  tmp_html <- tempfile(fileext = ".html")
  tools::pkg2HTML(pkg, out = tmp_html)

  # read in html
  og <- rvest::read_html(tmp_html)

  # get all of the elements
  all_elements <- og |>
    rvest::html_elements("main") |>
    rvest::html_children()


  # get reference positions
  reference_starts <- which(rvest::html_name(all_elements) == "h2" & !is.na(rvest::html_attr(all_elements, "id")))

  # count how many elements there are in the html file
  n <- length(all_elements)

  # identify the reference section ending positions
  reference_ends <- (reference_starts + diff(c(reference_starts, n))) - 1
  reference_ends[length(reference_ends)] <- length(all_elements)

  # extract all of the reference doc
  all_references <- Map(
    function(.x, .y) {
      # create a new html div with a "reference class"
      new_div <- rvest::read_html('<div class="reference"></div>') |>
        rvest::html_element("div")

      # identify all of the children from the reference section
      children <- all_elements[.x:.y]

      # for each of the children add it to the div
      for (child in children) {
        xml2::xml_add_child(new_div, child)
      }
      # return the div
      new_div
    },
    reference_starts, reference_ends
  )

  all_mds <- unlist(lapply(all_references, html_to_md))

  # adds the TOC to mimic the R function
  yaml_header <- c(
    "---",
    paste0("title: ", pkg),
    "---"
  )

  c(yaml_header, all_mds)
}

for (pkg in pkgs) {
  txt <- pkg_to_md(pkg)
  brio::write_lines(
    txt,
    paste0("~/github/arcgis-site/markdown/pkgs/", pkg, ".md")
  )
}
