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
 (synopsis "A Forester Preprocessor")
 (description "Graft is a tool for writing forester forests using markdown and bibtex")
 (depends
   ocaml
   (forester (>= "5.0"))
   cmarkit
   yaml
   talaria-bibtex
   (hilite (>= "0.5.0"))
   markup
   astring
   eio_main
  )
 (tags
  (forester)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
