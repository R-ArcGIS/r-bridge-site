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

    # extract header from the .qmd file
    header <- rmarkdown::yaml_front_matter(in_path)
    if (length(header) > 0) {
      md_header <- c("---", 
                      paste(names(header), header, sep = ": "), 
                      "---", "")
    } else {
      md_header <- character(0)
    }

  # create a temporary file to write to this is because rmarkdown::render cannot find
  # the appropriate directory and i have no idea why :/
  tmp <- tempfile(fileext = ".md")
  knitr::opts_chunk$set(comment = "#>")
  # render the section alone
  out <- rmarkdown::render(
    in_path,
    rmarkdown::github_document(),
    output_file = tmp,
    knit_root_dir = fs::path_abs(work_dir),
    quiet = TRUE
  )

  # create the output markdown file so that downlit can write to it
  file.create(out_path)

  # add autolinking and syntax highlighting (we will have to choose colors manually later)
  tryCatch({
    downlit::downlit_md_path(tmp, out_path = out_path)
    md_body <- readLines(tmp)
  }, error = function(e) {
      cli::cli_alert_danger("Failed apply downlit to {.file {in_path}}")
      md_body <- readLines(tmp)
      # file.copy(tmp, out_path, TRUE)
    }
  )
  final_content <- c(md_header, "", md_body)
  writeLines(final_content, out_path)
}


all_files <- list.files(
  c("images", "docs"),
  full.names = TRUE,
  all.files = TRUE,
  recursive = TRUE,
)

# all quarto docs
in_fps <- list.files(pattern = "*.qmd", recursive = TRUE)

# remove quarto docs from all_files
to_copy <- setdiff(all_files, in_fps)
copy_dest <- file.path("_arcgis", to_copy)

# remove the overview.qmd files
# in_fps <- in_fps[!basename(in_fps) == "overview.qmd"]

# define the output paths
out_fps <- paste0(
  tools::file_path_sans_ext(file.path("_arcgis", in_fps)),
  ".md"
)

# create directories
for (dirp in unique(dirname(c(out_fps, copy_dest)))) {
  if (!dir.exists(dirp)) {
    dir.create(dirp, recursive = TRUE)
  }
}

# copy all of the non-quarto files
file.copy(
  to_copy,
  copy_dest,
  overwrite = TRUE
)

source("dev/imgs.R")

# render all of the files
for (i in 1:length(in_fps)) {
  ip <- in_fps[[i]]
  op <- out_fps[[i]]
  cli::cli_alert_info("Rendering # file {i}: {.file {ip}} to {.file {op}}")
  # always unset the arcgis token first
  arcgisutils::unset_arc_token()
  render_qmd_to_md(ip, op)
}

zip::zip(
  "_docs.zip",
  list.files(
    "_arcgis",
    full.names = TRUE,
    recursive = TRUE
  )
)
