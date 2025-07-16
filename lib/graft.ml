module Pp = Pp
module Markdown = Markdown
module Bib = Bib

let ( / ) = Eio.Path.( / )

module Kind = struct
  type _ t = ..
  type markdown = Markdown
  type bibtex = Bibtex
  type tree = Tree
  type _ t += Markdown : markdown t | Bibtex : bibtex t | Tree : tree t
end

type 'kind preprocessor =
  Forester_core.Config.t ->
  Eio.Fs.dir_ty Eio.Path.t ->
  (Eio.Fs.dir_ty Eio.Path.t
  * [ `Code of Forester_core.Code.t | `String of string ])
  list

type pp = E : _ preprocessor -> pp

let tree_ext path =
  let res, f = path in
  let fname =
    try Filename.chop_extension f ^ ".tree"
    with Invalid_argument _ -> Fmt.invalid_arg "tree_ext: %s" f
  in
  (res, fname)

let markdown : Kind.markdown preprocessor =
 fun config path ->
  let document = Eio.Path.load path in
  [ (tree_ext path, `Code (Markdown.parse_doc ~config document)) ]

let bibtex : Kind.bibtex preprocessor =
 fun config path ->
  let bibfile = Eio.Path.load path in
  let bibs = Bib.parse_doc ~config bibfile in
  let dir =
    let res, p = path in
    (res, Filename.dirname p)
  in
  List.map
    (fun (key, tree) -> (Eio.Path.(dir / (key ^ ".tree")), `Code tree))
    bibs

let tree : Kind.tree preprocessor =
 fun _ path ->
  let tree = Eio.Path.load path in
  [ (path, `String tree) ]

let apply_pp config path (E pp) = pp config path

let ensure_dir p =
  try Eio.Path.mkdir ~perm:0o755 p
  with Eio.Io (Eio.Fs.E (Eio.Fs.Already_exists _), _) -> ()

let noop _ _ = []

let find_preprocessor ((_, name) as path) =
  match Filename.extension name with
  | ".md" -> E markdown
  | ".bib" -> E bibtex
  | ".tree" -> E tree
  | _ ->
      Fmt.epr "Unknown extension: %a\n%!" Eio.Path.pp path;
      E noop
  | exception e ->
      Fmt.epr "Error %a (%s)\n%!" Eio.Path.pp path (Printexc.to_string e);
      E noop

type t = { config : Forester_core.Config.t }

let v cwd =
  let toml = Eio.Path.(load (cwd / "forest.toml")) in
  let config =
    Forester_frontend.Config_parser.parse_forest_config_string toml
  in
  { config }

let process_file t path = find_preprocessor path |> apply_pp t.config path

let process t in_dir out_dir =
  ensure_dir out_dir;
  let rec loop ((_, rel) as path) =
    match Eio.Path.kind ~follow:false path with
    | `Regular_file ->
        let trees = process_file t path in
        Eio.Fiber.List.iter ~max_fibers:5
          (fun ((_, rel), code) ->
            Eio.Path.(mkdirs ~perm:0o755 ~exists_ok:true out_dir);
            let path = out_dir / rel in
            let content =
              match code with
              | `String s -> s
              | `Code c -> Fmt.str "%a" Pp.code c
            in
            Eio.Path.save ~create:(`Or_truncate 0o644) path content)
          trees
    | `Directory ->
        Eio.Path.(ensure_dir (out_dir / rel));
        Eio.Path.read_dir path |> List.iter (fun f -> loop (path / f))
    | `Not_found -> Fmt.failwith "process: kind not found"
    | #Eio.File.Stat.kind as k ->
        Fmt.failwith "process: unknown kind %a" Eio.File.Stat.pp_kind k
  in
  loop in_dir
