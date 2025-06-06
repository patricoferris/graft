graft
=====

Graft takes a [Forester](https://www.forester-notes.org) forest written in Markdown and Bibtex files
and produces a forest written in Forester syntax. The markdown syntax supports OCaml code highlighting
and passing through any HTML code blocks.

This is how my [personal website](https://patrick.sirref.org) is generated.

## Installation

For the moment we are tracking the 5.0 development branch of Forester.

```sh
opam pin git+https://github.com/patricoferris/graft
```

## Usage

`graft` simply preprocesses a forest generating Forester trees from `.md`, `.bib` and `.tree` files.
It will copy the structure of the input directory in the output directory.

```sh
$ graft preprocess --output=grafted-trees trees
$ forester build
```

This assumes that you have updated your Forester toml file to put to the `grafted-trees` directory.

```toml
[forest]
trees = [ "grafted-trees" ]
```



