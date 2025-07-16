graft
=====

Please refer to the [online documentation](https://graft.sirref.org) or alternatively
the markdown files in [the documentation folder](./docs).

## Installation

For the moment we are tracking the 5.0 development branch of Forester.

```sh
opam update
opam install graft
```

## Building Docs

Graft is used to build its own documentation.

```
dune exec -- graft preprocess --output=trees docs
forester build
```
