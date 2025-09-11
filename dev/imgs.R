img <- function(img, size) {
  sprintf(r"{<span style="display:inline-block; width: %i%%;"><img src="%s" width=%i%%/></span>}",  size, img, size)
}

