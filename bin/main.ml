open Webcamel

let run uri _ext =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level @@ Some Logs.Info;
  Logs.set_reporter (Logs_fmt.reporter ());
  Lwt_main.run (Main.crawl uri _ext)

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

let arg_external =
  let doc =
    "Crawl external links first" in
  Arg.(value & flag & info ["e"; "external"] ~docv:"EXTERNAL" ~doc)

(*let arg_connection_count =
  let doc =
    "Max connection in parallel (default 1)" in
  Arg.(value & opt int 1 & info ["c"; "conection"] ~doc)*)

let cmd =
  let doc = "Request URI, parse HTML, extract internal paths & external links and store data in irmin git db" in
  let man = [
    `S "DESCRIPTION";
    `P "$(tname) fetches remote $(i,URI) and then based on the response it parses HTML content. \
        Extracts anchor elements and their href attributes from parsed HTML content. It extracts \
        internal and external links and starts crawling internal links first unless $(i,EXTERNAL) \
        flag defined. It saves source code and analyzed data into the irmin git database";
    `S "BUGS";
    `P "Report then via e-mail to Erhan Gundogan <erhan.gundogan at gmail.com>." ]
  in
  Term.(pure run $ arg_uri $ arg_external),
  Term.info "webcamel" ~version:Webcamel.Version.v ~doc ~man

let () =
  match Term.eval cmd with
  | `Error _ -> exit 1
  | _ -> exit 0
