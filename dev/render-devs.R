#' Renders a quarto document to GitHub flavored Markdown.
#'
#' NOTE this will be imperfect. I think we may not get images to path correctly among other things
#' Let's not let perfect be the enemy of good.
#'
#' It will convert the :::{.class-name} into a <div class="class-name"> which is respected
#' by the markdown rendered we are using. Additionally, if there is any need to have a specific
#' working directory when rendering it, pass it into the `work_dir` path. This shouldn't be
#' necessary. Additionally, the {downlit} package is used to add automatic hyperlinking for us
#' like we would expect using {pkgdown}
#'
#' @param in_path a document to render. Uses {rmarkdown}
#' @param out_path the output filename. Should end in `.md`
#' @param work_dir the directory to "knit" the file in. Defaults to current dur.
#'
render_qmd_to_md <- function(in_path, out_path, work_dir = dirname(in_path)) {
  # set the output character to be #> is what prepends to output e.g.
  # print("Hello world")
  # #> [1] "Hello world"

  # create a temporary file to write to this is because rmarkdown::render cannot find
  # the appropriate directory and i have no idea why :/
  tmp <- tempfile(fileext = ".md")
  knitr::opts_chunk$set(comment = "#>")
  # render the section alone
  out <- rmarkdown::render(
    in_path,
    rmarkdown::github_document(),
    output_file = tmp,
    knit_root_dir = fs::path_abs(work_dir)
  )

  # create the output markdown file so that downlit can write to it
  file.create(out_path)

  # add autolinking and syntax highlighting (we will have to choose colors manually later)
  tryCatch(downlit::downlit_md_path(tmp, out_path = out_path), error = function(e) {
    cli::cli_alert_danger("Failed apply downlit to {.file {in_path}}")
    file.copy(tmp, out_path, TRUE)
  })
}


in_fps <- list.files(pattern = "*.qmd", recursive = TRUE)
out_fps <- paste0(tools::file_path_sans_ext(file.path("_arcgis", in_fps)), ".md")


# create directories
for (dirp in unique(dirname(out_fps))) {
  if (!dir.exists(dirp)) {
    dir.create(dirp, recursive = TRUE)
  }
}

# failed at 11 (docs)"_arcgis/docs/geocode/overview.md"
for (i in 1:length(in_fps)) {
  ip <- in_fps[[i]]
  op <- out_fps[[i]]
  cli::cli_alert_info("Rendering # file {i}: {.file {ip}} to {.file {op}}")
  render_qmd_to_md(ip, op)
}

render_qmd_to_md(in_fps[20], out_fps[20])
# Example
# render_qmd_to_md(
#   "location-services/publishing.qmd",
#   "markdown/publishing.md"
# )

