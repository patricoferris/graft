open Forester_core

type common = {
  kind : Bibtex.Fields.kind;
  title : string;
  authors : Bibtex.Fields.name list;
  year : int;
  doi : string list;
  abstract : string;
  journal : string option;
  url : string option;
}

let number =
  let of_string s =
    match int_of_string_opt s with Some i -> `Int i | None -> `String s
  in
  let to_string = function `Int i -> string_of_int i | `String s -> s in
  Bibtex.Fields.named_field ~name:"number"
    Bibtex.Fields.{ to_ = to_string; from = of_string }

let url = Bibtex.Fields.str_field ~name:"url"

let to_common (k, data) =
  let open Bibtex.Fields in
  match
    ( data.%{kind.f},
      data.%{title.f},
      data.%{authors.f},
      data.%{year.f},
      data.%{doi.f},
      data.%{abstract.f},
      data.%{journal.f},
      data.%{url.f} )
  with
  | ( Some kind,
      Some title,
      Some authors,
      Some year,
      doi,
      Some abstract,
      journal,
      url ) ->
      let doi = Option.value ~default:[] doi in
      Some (k, { kind; title; authors; year; doi; abstract; journal; url })
  | _ ->
      Fmt.epr "Warning: Skipping Bibtex Entry\n%!";
      None

let kind_to_string : Bibtex.Fields.kind -> string = function
  | Inproceedings -> "inproceedings"
  | Book -> "book"
  | Talk -> "talk"
  | Poster -> "poster"
  | Article -> "article"

let rec inline_string ?(emph = false) s =
  if emph then
    Cmarkit.Inline.Strong_emphasis
      ( Cmarkit.Inline.Emphasis.make (inline_string ~emph:false s),
        Cmarkit.Meta.none )
  else Cmarkit.Inline.Text (s, Cmarkit.Meta.none)

let string_value name = function None -> [] | Some v -> [ (name, `String v) ]

let parse_doc ~config s =
  let ( |>> ) database f =
    let open Bibtex.Fields in
    Database.add f.name (str f) database
  in
  let with_keys =
    Bibtex.Fields.Database.remove "number" Bibtex.Fields.default_keys
    |>> number |>> url
  in
  let data = Bibtex.parse ~with_keys @@ Lexing.from_string s in
  let entries = Bibtex.Database.to_list data |> List.filter_map to_common in
  let entry_to_document (key, c) =
    let authors =
      List.map
        (fun Bibtex.Fields.{ firstname; lastname } ->
          ("author", `String (Fmt.str "%s %s" firstname lastname)))
        c.authors
    in
    let nodes =
      `O
        ([
           ("title", `String c.title);
           ("date", `String (string_of_int c.year));
           ("taxon", `String "Reference");
           ("tag", `String (c.kind |> kind_to_string));
           ( "meta",
             `O
               ([ ("doi", Yaml.Util.string (String.concat "/" c.doi)) ]
               @ string_value "journal" c.journal
               @ string_value "external" c.url) );
         ]
        @ authors)
    in
    let lines = inline_string c.abstract in
    let md =
      Cmarkit.Doc.make
        (Cmarkit.Block.Blocks
           ( [
               Cmarkit.Block.Heading
                 ( Cmarkit.Block.Heading.make ~level:2 (inline_string "Abstract"),
                   Cmarkit.Meta.none );
               Cmarkit.Block.Paragraph
                 (Cmarkit.Block.Paragraph.make lines, Cmarkit.Meta.none);
             ],
             Cmarkit.Meta.none ))
    in
    let meta_nodes =
      List.map (Range.locate_opt None) @@ Markdown.code_of_yaml (Some nodes)
    in
    let body_nodes =
      Markdown.parse_doc ~config (Cmarkit_commonmark.of_doc md)
    in
    (key, meta_nodes @ body_nodes)
  in
  List.map entry_to_document entries
