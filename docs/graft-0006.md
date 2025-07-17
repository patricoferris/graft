---
title: Usage
date: 2025-07-14
---

To use [Graft]() you will need to install it via opam.

```
opam install graft
```

and after setting up a minimal [Forester project](https://www.forester-notes.org/0052/index.xml), you
can generate your forest using:

```
graft forest --output=trees
```

This assumes your `forest.toml` is set up to build from `trees`.
