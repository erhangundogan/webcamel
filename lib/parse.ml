open Lwt.Infix
open Soup

module USet = Set.Make(Uri)

type p_t = {
  uri: Uri.t;
  redirect: Uri.t option;
  content: string;
  headers: Graphql.Page.header list;
  locals: USet.t;
  globals: USet.t;
}

let get_uri_with_path uri = Uri.with_uri uri ~fragment:None ~query:None
let get_uri_without_path uri = Uri.with_uri uri ~fragment:None ~query:None ~path:None
let filter_by_scheme lst scheme = USet.filter (fun u -> (Option.get (Uri.scheme u)) = scheme) lst
let is_supported_scheme scheme =
  try Some (List.find (fun s -> s = scheme) Config.uri_schemes_supported)
  with Not_found -> None
let find_https_host uri list =
  let host = Uri.with_scheme uri (Some "https") in
  try Some (USet.find host list)
  with Not_found -> None
let unify_set_by_host ?(scheme1="http") ?(scheme2="https") set =
  let globals_http_list = filter_by_scheme set scheme1 in
  let globals_https_list = filter_by_scheme set scheme2 in
  let required_http_list = USet.filter (fun u ->
    Option.is_none (find_https_host u globals_https_list)) globals_http_list in
    USet.union globals_https_list required_http_list

let extract_urls soup =
  let rec aux acc = function
  | [] -> acc
  | h :: t -> aux (USet.add (Uri.of_string (R.attribute "href" h)) acc) t in
  aux USet.empty (soup $$ "a[href]" |> to_list)

let replace uri base_uri = Uri.with_uri uri
  ~scheme:(Uri.scheme base_uri)
  ~host:(Uri.host base_uri)
  ~port:(Uri.port base_uri)
  ~fragment:None
  ~query:None

let normalise_all base_uri items =
  USet.map (fun uri ->
    if Option.is_none (Uri.scheme uri)
    then replace uri base_uri
    else get_uri_with_path uri
  ) items

let validate_all items =
  USet.filter (fun uri -> Option.is_some (is_supported_scheme (Option.get (Uri.scheme uri)))) items

let get_links base_uri page_content =
  page_content
  |> parse
  |> extract_urls
  |> normalise_all base_uri
  |> validate_all

let filter_links ?(is_local=false) ?(is_global=false) ?(unify_scheme=true) ?(canonicalize=false) base_uri items =
  let has_same_host uri1 uri2 = Uri.((host uri1) = (host uri2)) in
  match is_local, is_global with
  | true, false -> USet.filter (fun uri -> has_same_host base_uri uri) items
  | false, true ->
    let globals_list = USet.map (fun uri ->
      let u = get_uri_without_path uri in if canonicalize then Uri.canonicalize u else u)
      (USet.filter (fun uri -> not @@ has_same_host base_uri uri) items) in
    if unify_scheme
    then unify_set_by_host globals_list
    else globals_list
  | _, _ -> failwith "Please select either is_local or is_global"

let start (uri: Uri.t): p_t Lwt.t =
  let time = Unix.gettimeofday () in
  Http.fetch uri >>= fun (content, headers, final_uri) ->
  let items = get_links uri content in
  let locals = filter_links uri items ~is_local:true in
  let globals = filter_links uri items ~is_global:true in
  Logs.info (fun m ->
    m "Total %d URL addresses extracted in %f secs. locals: %d, globals: %d"
    (USet.cardinal items) (Unix.gettimeofday () -. time)
    (USet.cardinal locals) (USet.cardinal globals));
  Lwt.return {
    uri;
    redirect = if (uri = final_uri) then None else Some final_uri;
    content;
    headers = List.map (fun (key, value) : Graphql.Page.header -> { key; value }) (Cohttp.Header.to_list headers);
    locals;
    globals;
  }

let pp ppf (item: p_t) =
  Format.fprintf ppf 
    "@[Request Item:@.Address: %s@.Redirected: %s@.Page length: %i@.Inbound links: %i@. Outbound links: %i]@."
    (Uri.to_string item.uri)
    (if Option.is_some item.redirect then Uri.to_string (Option.get item.redirect) else "")
    (String.length item.content)
    (USet.cardinal item.locals)
    (USet.cardinal item.globals)
    (*  print_endline "Headers:"; List.iter (fun (key, value) -> Printf.printf "[%s]: %s\n" key value) item.headers;*)
