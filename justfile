default:
  just --list

update:
  git add . && git commit -m "update" && git push
doc-ref:
  R -f dev/generate-api-ref.R

doc-pages:
  R -f dev/generate-docs.R
