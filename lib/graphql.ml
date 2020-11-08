open Lwt.Infix

module Page = struct
  type header = {
    key: string;
    value: string;
  }

  type t = {
    uri: string;
    redirect: string option;
    secure: bool;
    headers: header list;
    locals: string list;
    globals: string list;
    page: string;
  }

  let header =
    let open Irmin.Type in
    record "header" (fun key value -> { key; value })
    |+ field "key" string (fun t -> t.key)
    |+ field "value" string (fun t -> t.value)
    |> sealr

  let t =
    let open Irmin.Type in
    record "page" (fun uri redirect secure headers locals globals page ->
      { uri; redirect; secure; headers; locals; globals; page })
    |+ field "uri" string (fun t -> t.uri)
    |+ field "redirect" (option string) (fun t -> t.redirect)
    |+ field "secure" bool (fun t -> t.secure)
    |+ field "headers" (list header) (fun t -> t.headers)
    |+ field "locals" (list string) (fun t -> t.locals)
    |+ field "globals" (list string) (fun t -> t.globals)
    |+ field "page" string (fun t -> t.page)
    |> sealr

  let merge = Irmin.Merge.(option (idempotent t))
end

module Data_store = Irmin_unix.Git.FS.KV (Page)

module Custom_types = struct
  module Defaults = Irmin_graphql.Server.Default_types (Data_store)
  module Key = Defaults.Key
  module Metadata = Defaults.Metadata
  module Hash = Defaults.Hash
  module Branch = Defaults.Branch

  module Contents = struct
    open Graphql_lwt

    (* fun _ car -> Int32.to_int car.Car.year *)
    let header_typ =
      Schema.(
        obj "Header" ~fields:(fun _ ->
            [
              field "key" ~typ:(non_null string) ~args:[]
                ~resolve:(fun _ (p: Page.header) -> p.key);
              field "value" ~typ:(non_null string) ~args:[]
                ~resolve:(fun _ (p: Page.header) -> p.value);
            ]))

    let schema_typ =
      Schema.(
        obj "Page" ~fields:(fun _ ->
            [
              field "uri" ~typ:(non_null string) ~args:[]
                ~resolve:(fun _ p -> p.Page.uri);
              field "redirect" ~typ:(string) ~args:[]
                ~resolve:(fun _ p -> p.Page.redirect);
              field "secure" ~typ:(non_null bool) ~args:[]
                ~resolve:(fun _ p -> p.Page.secure);
              field "headers" ~typ:(non_null (list (non_null header_typ))) ~args:[]
                ~resolve:(fun _ p -> p.Page.headers);
              field "locals" ~typ:(non_null (list (non_null string))) ~args:[]
                ~resolve:(fun _ p -> p.Page.locals);
              field "globals" ~typ:(non_null (list (non_null string))) ~args:[]
                ~resolve:(fun _ p -> p.Page.globals);
              field "page" ~typ:(non_null string) ~args:[]
                ~resolve:(fun _ p -> p.Page.page);
            ]))

    let header_arg_typ =
      Schema.Arg.(
        obj "HeaderInput"
          ~fields:
            [
              arg "key" ~typ:(non_null string);
              arg "value" ~typ:(non_null string)
            ]
          ~coerce:(fun (key: string) (value: string) : Page.header -> { key; value })
      )

    let arg_typ =
      Schema.Arg.(
        obj "PageInput"
          ~fields:
            [
              arg "uri" ~typ:(non_null string);
              arg "redirect" ~typ:(string);
              arg "secure" ~typ:(non_null bool);
              arg "headers" ~typ:(non_null (list (non_null header_arg_typ)));
              arg "locals" ~typ:(non_null (list (non_null string)));
              arg "globals" ~typ:(non_null (list (non_null string)));
              arg "page" ~typ:(non_null string)
            ]
          ~coerce:(fun uri redirect secure headers locals globals page ->
            {
              Page.uri;
              redirect;
              secure;
              headers;
              locals;
              globals;
              page
            }))
  end
end

module Remote = struct
  let remote = Some Data_store.remote
end

module Server =
  Irmin_unix.Graphql.Server.Make_ext (Data_store) (Remote) (Custom_types)

let init () =
  let config = Irmin_git.config Config.details_irmin_root in
  Data_store.Repo.v config >>= fun repo ->
  let server = Server.v repo in
  let src = Config.graphql_server.host in
  let port = Config.graphql_server.port in
  Conduit_lwt_unix.init ~src () >>= fun ctx ->
  let ctx = Cohttp_lwt_unix.Net.init ~ctx () in
  let on_exn exn = Printf.printf "on_exn: %s" (Printexc.to_string exn) in
  Printf.printf "Visit GraphiQL @ http://%s:%d/graphql\n%!" src port;
  Cohttp_lwt_unix.Server.create ~on_exn ~ctx ~mode:(`TCP (`Port port)) server
