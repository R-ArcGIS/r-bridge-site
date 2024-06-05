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
  downlit::downlit_md_path(tmp, out_path = out_path)
}

# Example
# render_qmd_to_md(
#   "location-services/publishing.qmd",
#   "markdown/publishing.md"
# )
