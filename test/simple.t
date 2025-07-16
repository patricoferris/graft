A simple markdown file with some frontmatter.
  $ cat >foo.md <<EOF
  > ---
  > title: Hello
  > date: 2025-07-16
  > ---
  > 
  > Hello there !
  > EOF

Preprocessing a single tree

  $ graft tree foo.md
  \title{Hello}\date{2025-07-16}\p{Hello there !}

Metadata in the file is also stored in the frontmatter.
  $ cat >foo.md <<EOF
  > ---
  > title: Hello
  > date: 2025-07-16
  > meta:
  >   external: https://example.org
  > ---
  > 
  > Hello there !
  > EOF

And converted correctly.
  $ graft tree foo.md
  \title{Hello}\date{2025-07-16}\meta{external}{https://example.org}\p{Hello there !}

HTML is possible.

  $ cat >html.md <<EOF
  > <p>hello</p>
  > EOF

And converted to XML-forester syntax.

  $ graft tree html.md
  \xmlns:html{http://www.w3.org/1999/xhtml}\<html:p>{hello}

OCaml code is possible.

  $ cat >ocaml.md << EOF
  > ~~~ocaml
  > let x = 42
  > ~~~
  > EOF

And we convert it to syntax highlighted HTML.

  $ graft tree ocaml.md
  \xmlns:html{http://www.w3.org/1999/xhtml}\<html:pre>[class]{hilite}{\<html:code>{\<html:span>[class]{ocaml-keyword}{let}\<html:span>[class]{ocaml-source}{ }\<html:span>[class]{ocaml-entity-name-function-binding}{x}\<html:span>[class]{ocaml-source}{ }\<html:span>[class]{ocaml-keyword-operator}{=}\<html:span>[class]{ocaml-source}{ }\<html:span>[class]{ocaml-constant-numeric-decimal-integer}{42}\<html:span>[class]{ocaml-source}{
  }}}

