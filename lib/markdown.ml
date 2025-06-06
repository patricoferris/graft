open Forester_core
open Forester_compiler
open Astring

let parse_jekyll_format s =
  match String.cut ~sep:"---\n" s with
  | None -> Ok (None, Cmarkit.Doc.of_string ~strict:false s)
  | Some (fields, body) ->
      (* Start of the file, we might have YAML *)
      if String.is_empty fields then
        match String.cut ~sep:"---\n" body with
        | None -> Ok (None, Cmarkit.Doc.of_string ~strict:false s)
        | Some (fields, body) ->
            let fields_yml = Yaml.of_string fields in
            let body = Cmarkit.Doc.of_string ~strict:false body in
            let r = Result.map (fun f -> (Some f, body)) fields_yml in
            Result.map_error
              (function
                | `Msg m ->
                    Reporter.diagnostic Reporter.Message.Parse_error
                      ~text:(fun ppf -> Fmt.string ppf m))
              r
      else Ok (None, Cmarkit.Doc.of_string ~strict:false body)

let inline_to_string v =
  Cmarkit.Inline.to_plain_text ~break_on_soft:true v
  |> List.concat |> String.concat

let range_of_meta meta =
  let textloc = Cmarkit.Meta.textloc meta in
  let source = Cmarkit.Textloc.file textloc in
  let s_line, s_pos = Cmarkit.Textloc.first_line textloc in
  let e_line, e_pos = Cmarkit.Textloc.last_line textloc in
  let s_position : Range.position =
    {
      source = `File source;
      offset = s_pos;
      line_num = s_line;
      start_of_line = 0;
    }
  in
  let e_position : Range.position =
    {
      source = `File source;
      offset = e_pos;
      line_num = e_line;
      start_of_line = 0;
    }
  in
  Range.make (s_position, e_position)

let make_ident ?ident_range ?group_range ~ident cs : Code.t =
  let ident = Code.Ident [ ident ] in
  let rident = Range.locate_opt ident_range ident in
  let group = Code.Group (Braces, cs) in
  let rgroup = Range.locate_opt group_range group in
  [ rident; rgroup ]

let doc text =
  let item =
    Lsp.Types.TextDocumentItem.create ~languageId:"forester" ~text ~version:1
      ~uri:(Lsp.Uri.of_path "anon.tree")
  in
  let doc = Lsp.Types.DidOpenTextDocumentParams.create ~textDocument:item in
  Lsp.Text_document.make ~position_encoding:`UTF8 doc

let needs_verb s =
  not
  @@ String.for_all
       (function '{' | '}' | '[' | ']' | '(' | ')' | '%' -> false | _ -> true)
       s

type html =
  | Text of string
  | Element of string * (string * string) list * html list

let parse_html s =
  let open Markup in
  string s |> parse_html |> signals
  |> tree
       ~text:(fun ss -> Text (String.concat ~sep:"" ss))
       ~element:(fun (_, name) attrs children ->
         Element
           (name, List.map (fun ((_, name), v) -> (name, v)) attrs, children))
  |> function
  | None -> failwith "No HTML found!"
  | Some v -> v

let pp_html_attr fmt (name, value) = Fmt.pf fmt "[%s]{%s}" name value

let pp_attrs fmt = function
  | [] -> Fmt.nop fmt ()
  | attrs -> Fmt.(list ~sep:(Fmt.any "") pp_html_attr) fmt attrs

let convert_html_to_forester (html : html) =
  let buf = Buffer.create 128 in
  let rec loop : html -> unit = function
    | Element (name, attrs, rest) ->
        Buffer.add_string buf (Fmt.str "\\<html:%s>%a{" name pp_attrs attrs);
        List.iter loop rest;
        Buffer.add_string buf "}"
    | Text s -> Buffer.add_string buf s
  in
  loop html;
  Buffer.contents buf

let code_of_inline ?(end_space = false) folder acc (inline : Cmarkit.Inline.t) :
    Code.t Cmarkit.Folder.result =
  match inline with
  | Cmarkit.Inline.Text (s, meta) ->
      let range = range_of_meta meta in
      let s = if end_space then s ^ " " else s in
      let c = if needs_verb s then Code.Verbatim s else Text s in
      let code = Range.locate range c in
      Cmarkit.Folder.ret (acc @ [ code ])
  | Cmarkit.Inline.Code_span (span, meta) ->
      let txt = Cmarkit.Inline.Code_span.code span in
      let v = if needs_verb txt then Code.Verbatim txt else Code.Text txt in
      let c =
        make_ident ~ident_range:(range_of_meta meta) ~ident:"code"
          [ Range.locate_opt None v ]
      in
      Cmarkit.Folder.ret (acc @ c)
  | Cmarkit.Inline.Link (link, _meta) -> (
      let txt = Cmarkit.Inline.Link.text link in
      match
        Cmarkit.Inline.Link.reference_definition Cmarkit.Label.Map.empty link
      with
      | None -> `Default
      | Some (Cmarkit.Link_definition.Def (t, _)) -> (
          match Cmarkit.Link_definition.dest t with
          | None -> `Default
          | Some (lbl, meta) ->
              let f = Cmarkit.Folder.fold_inline folder [] txt in
              let txt' = Code.Group (Squares, f) |> Range.locate_opt None in
              let lbl =
                if lbl = "" then
                  let txt =
                    Cmarkit.Inline.to_plain_text ~break_on_soft:false txt
                  in
                  Stdlib.String.lowercase_ascii
                    (String.concat (List.concat txt))
                else lbl
              in
              let lbl = String.trim lbl in
              let c =
                if needs_verb lbl then Code.Verbatim lbl else Code.Text lbl
              in
              let link = Range.locate (range_of_meta meta) c in
              let ref =
                Code.Group (Parens, [ link ]) |> Range.locate_opt None
              in
              Cmarkit.Folder.ret (acc @ [ txt'; ref ]))
      | _ -> `Default)
  | Cmarkit.Inline.Inlines _ -> Cmarkit.Folder.default
  | Cmarkit.Inline.Emphasis (emph, _meta) ->
      let il = Cmarkit.Inline.Emphasis.inline emph in
      let c = Cmarkit.Folder.fold_inline folder [] il |> List.rev in
      let em = make_ident ~ident:"em" c in
      Cmarkit.Folder.ret (acc @ em)
  | Cmarkit.Inline.Strong_emphasis (emph, _meta) ->
      let il = Cmarkit.Inline.Emphasis.inline emph in
      let c = Cmarkit.Folder.fold_inline folder [] il |> List.rev in
      let em = make_ident ~ident:"strong" c in
      Cmarkit.Folder.ret (acc @ em)
  | Cmarkit.Inline.Break (break, meta) -> (
      match Cmarkit.Inline.Break.type' break with
      | `Hard -> Cmarkit.Folder.default
      | `Soft ->
          let range = range_of_meta meta in
          let code = Range.locate range (Code.Text " ") in
          Cmarkit.Folder.ret (acc @ [ code ]))
  | Cmarkit.Inline.Ext_math_span (m, meta) ->
      let math = Cmarkit.Inline.Math_span.tex m in
      let math = Range.locate_opt None (Code.Text math) in
      let code =
        if Cmarkit.Inline.Math_span.display m then Code.Math (Display, [ math ])
        else Code.Math (Inline, [ math ])
      in
      let range = range_of_meta meta in
      let code = Range.locate range code in
      Cmarkit.Folder.ret (acc @ [ code ])
  | _ -> Cmarkit.Folder.default

let code_of_block ~config ?(wrap = true) folder acc (block : Cmarkit.Block.t) :
    Code.t Cmarkit.Folder.result =
  match block with
  | Cmarkit.Block.Paragraph (para, meta) ->
      let range = range_of_meta meta in
      let inline = Cmarkit.Block.Paragraph.inline para in
      (* let end_space_folder = Cmarkit.Folder.make ~block:(code_of_block ~config) ~inline:(code_of_inline ~end_space:true) () in *)
      let codes = Cmarkit.Folder.fold_inline folder [] inline in
      let code =
        if wrap then make_ident ~group_range:range ~ident:"p" codes else codes
      in
      Cmarkit.Folder.ret (acc @ code)
  | Cmarkit.Block.Blocks _ -> Cmarkit.Folder.default
  | Cmarkit.Block.List (list, _meta) ->
      let elements = Cmarkit.Block.List'.items list |> List.map fst in
      let blocks = List.map Cmarkit.Block.List_item.block elements in
      let codes = List.map (Cmarkit.Folder.fold_block folder []) blocks in
      (* let codes = map_blocks ~config ~wrap:false folder [] blocks in *)
      let lis = List.concat_map (fun c -> make_ident ~ident:"li" c) codes in
      let ul =
        make_ident
          ~ident:
            (if
               Cmarkit.Block.List'.type' list |> function
               | `Unordered _ -> true
               | _ -> false
             then "ul"
             else "ol")
          lis
      in
      Cmarkit.Folder.ret (acc @ ul)
  | Cmarkit.Block.Code_block (cb, _meta) -> (
      let lang = Cmarkit.Block.Code_block.info_string cb in
      match lang with
      | Some ("forester", _) -> (
          (* This allows us to escape into Forester syntax and do whatever. *)
          let lines =
            Cmarkit.Block.Code_block.code cb
            |> List.map fst |> String.concat ~sep:"\n"
          in
          let codes = Parse.parse_document ~config (doc lines) in
          match codes with
          | Ok c -> Cmarkit.Folder.ret (acc @ c.nodes)
          | Error diagnostic -> Reporter.fatal_diagnostic diagnostic)
      | Some ("html", _) ->
          let lines =
            Cmarkit.Block.Code_block.code cb
            |> List.map fst |> String.concat ~sep:"\n"
          in
          let html = convert_html_to_forester (parse_html lines) in
          let html = "\\xmlns:html{http://www.w3.org/1999/xhtml}\n" ^ html in
          let codes =
            Parse.parse_document ~config (doc html) |> Result.get_ok
          in
          Cmarkit.Folder.ret (acc @ codes.nodes)
      | Some (lang, _) -> (
          let lines =
            Cmarkit.Block.Code_block.code cb
            |> List.map fst |> String.concat ~sep:"\n"
          in
          match Hilite.src_code_to_pairs ~escape:false ~lang lines with
          | Ok spans ->
              let mk_span (class_, code) =
                let code =
                  if needs_verb code then Fmt.str "\\verb<<|%s<<" code else code
                in
                Fmt.str "\\<html:span>[class]{%s}{%s}" class_ code
              in
              let html =
                spans
                |> List.map (List.map mk_span)
                |> List.map (fun s -> s @ [ "\n" ])
                |> List.concat
              in
              let html = List.rev html |> List.tl |> List.rev in
              let html =
                "\\xmlns:html{http://www.w3.org/1999/xhtml}\n"
                :: "\\<html:pre>[class]{hilite}{\\<html:code>{" :: html
                @ [ "}"; "}" ]
              in
              let codes =
                try
                  Parse.parse_document ~config
                    (doc (String.concat ~sep:"" html))
                  |> Result.get_ok
                with ex ->
                  Fmt.pr "Failed to parse %s" lines;
                  raise ex
              in
              Cmarkit.Folder.ret (acc @ codes.nodes)
          | _ ->
              let code = make_ident ~ident:"pre" in
              let block =
                code [ Range.locate_opt None (Code.Verbatim lines) ]
              in
              Cmarkit.Folder.ret (acc @ block))
      | _ ->
          let code = make_ident ~ident:"pre" in
          let lines =
            Cmarkit.Block.Code_block.code cb
            |> List.map fst |> String.concat ~sep:"\n"
            |> fun s -> Code.Verbatim s
          in
          let block = code [ Range.locate_opt None lines ] in
          Cmarkit.Folder.ret (acc @ block))
  | Cmarkit.Block.Block_quote (q, _meta) ->
      let quote = make_ident ~ident:"blockquote" in
      let content =
        Cmarkit.Block.Block_quote.block q |> Cmarkit.Folder.fold_block folder []
      in
      Cmarkit.Folder.ret (acc @ quote content)
  (* | Cmarkit.Block.Thematic_break (_, _meta) -> *)
  (*     let c = make_ident ~ident:"hr" [] in *)
  (*     Cmarkit.Folder.ret (acc @ c) *)
  | _ -> Cmarkit.Folder.ret acc

(* We interpret headings as subtrees, so we first convert a document
   into a tree based on the headings. *)
type 'a tree = 'a node list

and 'a node = {
  heading : Cmarkit.Inline.t;
  level : int;
  value : 'a;
  children : 'a node list;
}

let pp_tree pp_v ppf =
  let rec pp_subtree ppf = function
    | { children = s; heading; value; _ } ->
        let heading = inline_to_string heading in
        Format.fprintf ppf "{@[<hov 2>(%i)%s%a%a@]}" (List.length s) heading
          pp_v value
          Format.(pp_print_list pp_subtree)
          s
  in
  Format.pp_print_list pp_subtree ppf

let fold ~f ~acc v =
  let rec aux acc f = function
    | { children = []; value = v; _ } -> f acc v
    | { children = sections; _ } ->
        List.fold_left (fun a v -> aux a f v) acc sections
  in
  aux acc f v

let rec insert_node node = function
  | [] -> [ node ]
  | parent :: rest ->
      if node.level > parent.level then
        { parent with children = insert_node node parent.children } :: rest
      else node :: parent :: rest

let rec add_block_to_level ~level block = function
  | [] -> assert false
  | node :: rest ->
      if Int.equal node.level level then
        { node with value = node.value @ [ block ] } :: rest
      else
        { node with children = add_block_to_level ~level block node.children }
        :: rest

let doc_to_tree doc : Cmarkit.Block.t list * Cmarkit.Block.t list tree =
  let block _folder (current_level, toplevel, nodes) = function
    | Cmarkit.Block.Heading (h, _meta) ->
        let level = Cmarkit.Block.Heading.level h in
        let heading = Cmarkit.Block.Heading.inline h in
        let node = { heading; level; children = []; value = [] } in
        let nodes = insert_node node nodes in
        Cmarkit.Folder.ret (level, toplevel, nodes)
    | Cmarkit.Block.Blocks (_bs, _) ->
        (* As the docs say, "thread the fold" *)
        Cmarkit.Folder.default
    | block -> (
        match nodes with
        | [] -> Cmarkit.Folder.ret (current_level, toplevel @ [ block ], nodes)
        | _ :: _ ->
            let nodes = add_block_to_level ~level:current_level block nodes in
            Cmarkit.Folder.ret (current_level, toplevel, nodes))
  in
  let folder = Cmarkit.Folder.make ~block () in
  let _, top, nodes = Cmarkit.Folder.fold_doc folder (1, [], []) doc in
  (top, List.rev nodes)

let code_of_doc ~config doc : Code.t =
  let folder =
    Cmarkit.Folder.make ~block:(code_of_block ~config) ~inline:code_of_inline ()
  in
  Cmarkit.Folder.fold_doc folder [] doc

let title ~config il =
  Cmarkit.Folder.make ~block:(code_of_block ~config) ~inline:code_of_inline ()
  |> fun f -> Cmarkit.Folder.fold_inline f [] il |> make_ident ~ident:"title"

let rec tree_to_code : Config.t -> Cmarkit.Block.t list tree -> Code.t =
 fun config -> function
  | { children; value = blocks; heading; _ } :: rest ->
      let children = List.rev children in
      let title = title ~config heading in
      let c =
        Cmarkit.Doc.make (Cmarkit.Block.Blocks (blocks, Cmarkit.Meta.none))
      in
      let current = code_of_doc ~config c in
      let codes = tree_to_code config children in
      (Range.locate_opt None @@ Code.Subtree (None, title @ current @ codes))
      :: tree_to_code config rest
  | [] -> []

let code_of_yaml = function
  | None -> []
  | Some (`O assoc) ->
      let make_group s =
        Code.Group (Braces, [ Range.locate_opt None (Code.Text s) ])
      in
      let rec extract_meta acc = function
        | [] -> (None, List.rev acc)
        | ("meta", `O v) :: rest -> (Some v, List.rev acc @ rest)
        | x :: rest -> extract_meta (x :: acc) rest
      in
      let meta, assoc = extract_meta [] assoc in
      let codes =
        List.fold_left
          (fun acc (k, v) ->
            let id = Code.Ident [ k ] in
            match v with
            | `String s -> id :: make_group s :: acc
            | `Float f -> id :: (make_group @@ string_of_float f) :: acc
            | `Bool b -> id :: (make_group @@ string_of_bool b) :: acc
            | _ -> acc)
          [] (List.rev assoc)
      in
      let meta_codes =
        match meta with
        | None -> []
        | Some assoc ->
            let cs =
              List.fold_left
                (fun acc -> function
                  | k, `String s ->
                      Code.Ident [ "meta" ] :: make_group k :: make_group s
                      :: acc
                  | k, `Bool b ->
                      Code.Ident [ "meta" ] :: make_group k
                      :: make_group (string_of_bool b)
                      :: acc
                  | _ -> acc)
                [] assoc
            in
            cs
      in
      codes @ meta_codes
  | _ -> []

let parse_doc ~config doc =
  let toplevel, tree = doc_to_tree doc in
  let toplevel_codes =
    Cmarkit.Doc.make (Cmarkit.Block.Blocks (toplevel, Cmarkit.Meta.none))
    |> code_of_doc ~config
  in
  let codes = tree_to_code config tree in
  toplevel_codes @ codes

let parse_doc ~config s =
  match parse_jekyll_format s with
  | Error e -> Reporter.fatal_diagnostic e
  | Ok (yml, doc) ->
      let yml_codes = List.map (Range.locate_opt None) @@ code_of_yaml yml in
      let body_codes = parse_doc ~config doc in
      yml_codes @ body_codes
