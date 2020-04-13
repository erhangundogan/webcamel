open Webcamel

let run uri _int _ext =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level @@ Some Logs.Info;
  Logs.set_reporter (Logs_fmt.reporter ());
  Lwt_main.run (Main.crawl uri)

open Cmdliner

let arg_uri =
  let doc = "URI/URL to make a request through either HTTP or HTTPS schemes." in
  let loc: Uri.t Arg.converter =
    let parse s =
      try `Ok (Uri.of_string s)
      with Failure _ -> `Error "unable to parse URI" in
    parse, fun ppf p -> Format.fprintf ppf "%s" (Uri.to_string p)
  in
  Arg.(required & pos 0 (some loc) None & info [] ~docv:"URI" ~doc)

let arg_internal =
  let doc =
    "Crawl internal web site with all paths" in
  Arg.(value & flag & info ["i"; "internal"] ~doc)

let arg_external =
  let doc =
    "Crawl external domains (n) iterations (default None)" in
  Arg.(value & opt (some int) None & info ["e"; "external"] ~doc)

(*let arg_connection_count =
  let doc =
    "Max connection in parallel (default 1)" in
  Arg.(value & opt int 1 & info ["c"; "conection"] ~doc)*)

let cmd =
  let doc = "Retrieve a remote URI content and extract URLs" in
  let man = [
    `S "DESCRIPTION";
    `P "$(tname) fetches the remote $(i,URI) and then parse HTML content. \
        Then extracts anchor elements' href attributes to continue crawling \
        the web. It can save source code and data into git database";
    `S "BUGS";
    `P "Report then via e-mail to Erhan Gundogan <erhan.gundogan at gmail.com>." ]
  in
  Term.(pure run $ arg_uri $ arg_internal $ arg_external),
  Term.info "webcamel" ~version:Webcamel.Version.v ~doc ~man

let () =
  match Term.eval cmd with
  | `Error _ -> exit 1
  | _ -> exit 0
