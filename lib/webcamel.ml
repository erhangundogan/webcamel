open Lwt.Infix
open Cohttp_lwt
open Cohttp_lwt_unix
open Soup

module USet = Set.Make(Uri)

type t = {
  uri: Uri.t;
  redirect: Uri.t option;
  content: string;
  headers: (string * string) list;
  locals: USet.t;
  globals: USet.t;
}

let pp result =
  Printf.printf "Address:\n%s\n\n" (Uri.to_string result.uri);
  if Option.is_some result.redirect
  then Printf.printf "Redirected:\n%s\n\n" (Uri.to_string (Option.get result.redirect))
  else ();
  print_endline "Content:";
  Printf.printf "Page length: %d\n\n" (String.length result.content);
  print_endline "Headers:";
  List.iter (fun (key, value) -> Printf.printf "[%s]: %s\n" key value) result.headers;
  Printf.printf "\nLocals: Total count %d\n" (USet.cardinal result.locals);
  USet.iter (fun link -> print_endline (Uri.to_string link)) result.locals;
  Printf.printf "\nGlobals: Total count %d\n" (USet.cardinal result.globals);
  USet.iter (fun link -> print_endline (Uri.to_string link)) result.globals

let version = "0.1.0"

let extract_urls soup =
  let rec aux acc = function
  | [] -> acc
  | h :: t -> aux (USet.add (Uri.of_string (R.attribute "href" h)) acc) t in
  aux USet.empty (soup $$ "a[href]" |> to_list)

let normalise_all base_uri items =
  let replace uri = Uri.with_uri uri
    ~scheme:(Uri.scheme base_uri)
    ~host:(Uri.host base_uri)
    ~fragment:None
    ~query:None
  in
  let minify uri = Uri.with_uri uri
    ~fragment:None
    ~query:None
  in
  USet.map (fun uri ->
    if Option.is_none (Uri.scheme uri)
    then replace uri
    else minify uri
  ) items

let validate_all items =
  USet.filter (fun uri ->
    let scheme = Option.get (Uri.scheme uri) in
    scheme = "http" || scheme = "https"
  ) items

let get_links base_uri page_content =
  page_content
  |> parse
  |> extract_urls
  |> normalise_all base_uri
  |> validate_all

let has_same_host uri1 uri2 =
  (Uri.scheme uri1) = (Uri.scheme uri2) && (Uri.host uri1) = (Uri.host uri2)

let filter_links ?(is_local=false) ?(is_global=false) base_uri items =
  match is_local, is_global with
  | true, false -> USet.filter (fun uri -> has_same_host base_uri uri) items
  | false, true -> USet.filter (fun uri -> not @@ has_same_host base_uri uri) items
  | _, _ -> failwith "Please select true either is_local or is_global argument"

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
      ("user-agent","WebCamel/" ^ version);
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

let start address =
  let t = Unix.gettimeofday () in
  let uri = Uri.of_string address in
  fetch uri >>= fun (content, headers, final_uri) ->
  let items = get_links uri content in
  let locals = filter_links uri items ~is_local:true ~is_global:false in
  let globals = filter_links uri items ~is_local:false ~is_global:true in
  Logs.info (fun m ->
    m "Total %d URL addresses extracted in %f secs. locals: %d, globals: %d"
    (USet.cardinal items) (Unix.gettimeofday () -. t)
    (USet.cardinal locals) (USet.cardinal globals));
  Lwt.return {
    uri;
    redirect = if (uri = final_uri) then None else Some final_uri;
    content;
    headers = Cohttp.Header.to_list headers;
    locals;
    globals;
  }
