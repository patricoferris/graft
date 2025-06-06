(lang dune 3.19)

(name graft)

(generate_opam_files true)

(source
 (github patricoferris/graft))

(authors "Patrick Ferris <patrick@sirref.org>")

(maintainers "Patrick Ferris <patrick@sirref.org>")

(license MIT)

(package
 (name graft)
 (synopsis "Map and merge your forests")
 (description "Graft is a tool for writing forests in forester in other markups")
 (depends
   ocaml
   forester
   cmarkit
   yaml
   talaria-bibtex
   astring
   eio_main
  )
 (tags
  (forester)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
