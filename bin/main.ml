open Cmdliner

let ( / ) = Eio.Path.( / )

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

let preprocess_term =
  Term.(const preprocess_cmd $ input_dir_arg $ output_dir_arg)

let preprocess_info =
  let doc = "Preprocess a Forester forest of trees." in
  Cmd.info "preprocess" ~doc

let graft_cmd =
  let doc = "Graft preprocesses your forests." in
  Cmd.group (Cmd.info "graft" ~doc) [ Cmd.v preprocess_info preprocess_term ]

let () = exit (Cmd.eval graft_cmd)
