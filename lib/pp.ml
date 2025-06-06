open Forester_core.Code

let rec node ppf = function
  | Text s -> Fmt.string ppf s
  | Verbatim s -> Fmt.pf ppf "\\verb<<|%s<< " s
  | Group (Squares, t) -> Fmt.pf ppf "[%a]" code t
  | Group (Braces, t) -> Fmt.pf ppf "{%a}" code t
  | Group (Parens, t) -> Fmt.pf ppf "(%a)" code t
  | Ident path -> Fmt.pf ppf "\\%a" Forester_core.Trie.pp_path path
  | Subtree (None, t) -> Fmt.pf ppf "\n\\subtree{\n %a\n}" code t
  | Subtree (Some name, t) -> Fmt.pf ppf "\n\\subtree[%s]{\n %a\n}" name code t
  | Xml_ident (None, t) -> Fmt.pf ppf "\\<%s>" t
  | Xml_ident (Some v, t) -> Fmt.pf ppf "\\<%s:%s>" v t
  | Decl_xmlns (s, u) -> Fmt.pf ppf "\\xmlns:%s{%s}" s u
  | Put (path, t) ->
      Fmt.pf ppf "\\put\\%a{%a}" Forester_core.Trie.pp_path path code t
  | v -> Fmt.failwith "No printer for %a" pp_node v

and located pp ppf t = pp ppf t.Forester_core.Range.value
and code ppf = Fmt.list ~sep:Fmt.nop (located node) ppf
