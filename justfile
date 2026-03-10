default:
  just --list

doc-ref:
  R -f dev/generate-api-ref.R

doc-pages:
  R -f dev/generate-docs.R
