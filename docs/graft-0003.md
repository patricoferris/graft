---
title: YAML Frontmatter
date: 2025-07-14
---

The markdown format for [Graft]() follows the Jekyll-style YAML
frontmatter format. For example:

~~~
---
title: Hello, World!
date: 2025-07-14
---

This is a valid tree.
~~~

will generate a tree with `title` and `date` metadata with a single paragraph
of text.

To insert `meta` field into your tree, you can use a nested object in your YAML
frontmatter.

~~~
---
title: Meta fields!
meta:
  external: http://example.org
---

External links ! 
~~~

There is no centralised documentation on these `meta` fields (that I could find),
but this [biographical tree example may be useful](https://www.forester-notes.org/007K/index.xml)
