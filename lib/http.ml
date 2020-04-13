open Lwt.Infix
open Cohttp_lwt
open Cohttp_lwt_unix

let is_redirection status =
  Cohttp.Code.(code_of_status status |> is_redirection)

let get_location headers base_uri =
  let location = Cohttp.Header.get headers "location" in
  match location with
  | None -> failwith "Redirect location not specified!"
  | Some s ->
    let uri = Uri.of_string s in
    if (Option.is_some (Uri.host uri))
    then uri
    else Uri.with_uri uri ~scheme:(Uri.scheme base_uri) ~host:(Uri.host base_uri)

let headers =
  let key_values = Config.web_client_headers in
  Cohttp.Header.(add_list (init ()) key_values)

let rec fetch uri =
  Logs.info (fun m -> m "Fetching: %s" (Uri.to_string uri));
  Client.get ~headers uri >>= fun (res, body) ->
    if is_redirection res.status
    then
      get_location res.headers uri
      |> fun loc -> Logs.info (fun m ->
        m "%s is redirecting to %s" (Uri.to_string uri) (Uri.to_string loc));
        fetch loc
    else
      Body.to_string body >>= fun body -> Lwt.return (body, res.headers, uri)
