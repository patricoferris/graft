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
