---
title: Forester Code Blocks
date: 2025-07-14
---

The markdown syntax cannot do everything that [Forester]() can. For example,
how might you [transclude another tree into your tree]()?

At any given moment, you can escape into Forester syntax by using a code block
where the `infostring` is `forester`. [Graft]() will translate this into [Forester]()
syntax and output it in the same location as the code block in the generated code.

~~~
```forester
\put\transclude/numbered{false}
\transclude{graft-0001}
```
~~~
