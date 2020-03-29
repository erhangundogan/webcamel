open Lwt.Infix
open Webcamel

let crawl address =
  Parse.start (Uri.to_string address) >>= Store.save

let recall address =
  Store.Data.load (Uri.to_string address) >|= fun store_item -> Store.Data.pp store_item

let run arg_uri =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level @@ Some Logs.Info;
  Logs.set_reporter (Logs_fmt.reporter ());
  Lwt_main.run (crawl arg_uri)

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
  Term.(pure run $ arg_uri),
  Term.info "webcamel" ~version:Webcamel.Version.v ~doc ~man

let () =
  match Term.eval cmd with
  | `Error _ -> exit 1
  | _ -> exit 0
