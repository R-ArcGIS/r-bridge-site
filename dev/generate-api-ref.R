#' Requires:
#' pkgdown
#' gert
#' rvest
#' cli
#' arcgis

generate_api_ref <- function(pkg) {
  tmp <- tempdir()
  clone_dir <- file.path(tmp, pkg)

  if (file.exists(clone_dir)) {
    unlink(clone_dir, recursive = TRUE)
  }
  # clone into a temporary directory
  gert::git_clone(
    sprintf("https://github.com/r-arcgis/%s", pkg),
    path = clone_dir
  )
  
  # init pkgdown in the temporary folder
  pkgdown::init_site(clone_dir)
  # generate reference docs
  pkgdown::build_reference(clone_dir, preview = FALSE)
  
  all_pkg_files <- list.files(
    file.path(clone_dir, "docs", "reference"),
    recursive = TRUE,
    full.names = TRUE,
  )
  
  # create the api reference directory for the package
  dir.create(
    file.path("_api_ref", pkg),
    recursive = TRUE
  )
  
  # identify all of the directories we need to create
  dirs_to_create <- unique(
    dirname(
      file.path(
        "_api_ref",
        pkg,
        gsub(file.path(clone_dir, "docs", "reference", ""), "", all_pkg_files)
      )
    )
  )
  
  # create all of the directories 
  for (dir in dirs_to_create) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  
  # subset to only the function references 
  is_html <- tools::file_ext(all_pkg_files) == "html"
  fn_ref_html <- all_pkg_files[is_html]
  
  # copy the non-html files over
  to_copy <- all_pkg_files[!is_html]
  copy_dest <- file.path(
    "_api_ref",
    pkg,
    vapply(strsplit(to_copy, "reference/"), `[[`, character(1), 2)
  )
  
  file.copy(to_copy, copy_dest, overwrite = TRUE)
  
  # this function extract the html content 
  extract_fn_ref <- function(fp) {
      rvest::read_html(fp) |> 
          rvest::html_nodes("#main") |> 
          as.character()
  }
  
  # apply to all html files
  extracted <- lapply(fn_ref_html, extract_fn_ref)
  out_ref_paths <- file.path("_api_ref", pkg, basename(fn_ref_html))
  
  # write the html files
  Map(
    function(.html, .path) {
      cli::cli_alert_info("Writing {.file {(.path)}}")
      writeLines(.html, .path)
    },
    extracted,
    out_ref_paths
  )
  
  # Process the index file 
  index_html <- 
    rvest::read_html(file.path(clone_dir, "docs", "reference", "index.html")) |> 
    rvest::html_nodes("#main") |> 
    rvest::html_children() |> 
    as.character() 
  
  writeLines(
    # re-path the logo 
    sub("../logo.svg", "figures/logo.svg", index_html),
    file.path("_api_ref", pkg, "index.html")
  )
  
  unlink(tmp)
  
}


for (pkg in arcgis::arcgis_packages()) {
  generate_api_ref(pkg)
}