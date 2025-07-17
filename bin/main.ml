open Cmdliner

let ( / ) = Eio.Path.( / )

let single_file_cmd file =
  Eio_main.run @@ fun env ->
  let fs = Eio.Stdenv.fs env in
  let config = Graft.v fs in
  let path = Eio.Path.(fs / file) in
  let trees = Graft.process_file config path in
  List.iter
    (fun (_, v) ->
      match v with
      | `String s -> Fmt.pr "%s\n" s
      | `Code c -> Fmt.pr "%a\n" Graft.Pp.code c)
    trees

let preprocess_cmd input_dir output_dir =
  Eio_main.run @@ fun env ->
  let cwd = Eio.Stdenv.cwd env in
  let config = Graft.v cwd in
  Eio.Path.mkdirs ~exists_ok:true ~perm:0o755 (cwd / output_dir);
  Eio.Path.with_open_dir (cwd / input_dir) @@ fun in_dir ->
  Eio.Path.with_open_dir (cwd / output_dir) @@ fun out_dir ->
  Graft.process config in_dir out_dir

let input_dir_arg =
  let doc = "Input directory containing the Forester forest." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"INPUT_DIR" ~doc)

let output_dir_arg =
  let doc = "Output directory where preprocessed data will be written." in
  Arg.(
    required
    & opt (some string) None
    & info [ "output"; "o" ] ~docv:"OUTPUT_DIR" ~doc)

let input_file =
  let doc = "Input file (- for stdin)." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"INPUT_FILE" ~doc)

let single_file_term = Term.(const single_file_cmd $ input_file)

let single_file_info =
  let doc = "Preprocess a single tree." in
  Cmd.info "tree" ~doc

let preprocess_term =
  Term.(const preprocess_cmd $ input_dir_arg $ output_dir_arg)

let preprocess_info =
  let doc = "Preprocess a Forester forest of trees." in
  Cmd.info "forest" ~doc

let graft_cmd =
  let doc = "Graft preprocesses your forests." in
  Cmd.group (Cmd.info "graft" ~doc)
    [
      Cmd.v single_file_info single_file_term;
      Cmd.v preprocess_info preprocess_term;
    ]

let () = exit (Cmd.eval graft_cmd)
