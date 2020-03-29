open Lwt.Infix
open Cohttp_lwt
open Cohttp_lwt_unix

let rec fetch uri =
  let get_location headers =
    let location = Cohttp.Header.get headers "location" in
    match location with
    | None -> failwith "Redirect location not specified!"
    | Some s -> s in
  let is_redirection status =
    Cohttp.Code.(code_of_status status |> is_redirection) in
  let headers =
    let key_values = [
      ("user-agent","Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/74.0");
      ("accept","text/html");
      ("accept-language","en-US,en;q=0.5")
    ] in
    Cohttp.Header.(add_list (init ()) key_values) in
  Logs.info (fun m -> m "Fetching: %s" (Uri.to_string uri));
  Client.get ~headers uri >>= fun (res, body) ->
    if is_redirection res.status
    then
      get_location res.headers
      |> fun loc -> Logs.info (fun m ->
        m "%s is redirecting to %s" (Uri.to_string uri) loc);
        fetch (Uri.of_string loc)
    else
      Body.to_string body >>= fun body -> Lwt.return (body, res.headers, uri)
