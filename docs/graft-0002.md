---
title: Bibtex Syntax
date: 2025-07-14
---

The bibtex syntax allows you to generate individual `reference` trees per
entry.

For example, consider the following bibtex entry.

```
@article{mokhov-build-systems,
    author = {Mokhov, Andrey and Mitchell, Neil and Jones, Simon},
    title = {Build systems a la carte},
    year = {2018},
    issue_date = {September 2018},
    publisher = {Association for Computing Machinery},
    address = {New York, NY, USA},
    volume = {2},
    url = {https://doi.org/10.1145/3236774},
    doi = {10.1145/3236774},
    abstract = {Build systems are awesome, terrifying -- and unloved...},
    journal={Proceedings of the ACM on Programming Languages},
    articleno = {79},
    numpages = {29},
    keywords = {functional programming, build systems, algorithms}
}
```

We have placed this in a file called `refs.bib` and can [directly reference
the entry with `mokhov-build-systems`](mokhov-build-systems)!


<p style="background-color: lightyellow; padding: 1em;">
<strong>Warning</strong>: the bibtex is quite fragile due to the parser we use. At some point
I hope to help make this better. Using the above entry as an example would be wise. For example,
middle name initials are not supported in author names.
</p>
