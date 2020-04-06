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

let filter_links ?(is_local=false) ?(is_global=false) base_uri items =
  let has_same_host uri1 uri2 =
    Uri.((scheme uri1) = (scheme uri2) && (host uri1) = (host uri2)) in
  match is_local, is_global with
  | true, false -> USet.filter (fun uri -> has_same_host base_uri uri) items
  | false, true -> USet.filter (fun uri -> not @@ has_same_host base_uri uri) items
  | _, _ -> failwith "Please select true either for is_local or is_global"

let start (uri: Uri.t): p_t Lwt.t =
  let time = Unix.gettimeofday () in
  Http.fetch uri >>= fun (content, headers, final_uri) ->
  let items = get_links uri content in
  let locals = filter_links uri items ~is_local:true ~is_global:false in
  let globals = filter_links uri items ~is_local:false ~is_global:true in
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

let pp (item: p_t) =
  Printf.printf "Address:\n%s\n\n" (Uri.to_string item.uri);
  if Option.is_some item.redirect
  then Printf.printf "Redirected:\n%s\n\n" (Uri.to_string (Option.get item.redirect))
  else ();
  print_endline "Content:";
  Printf.printf "Page length: %d\n\n" (String.length item.content);
(*  print_endline "Headers:";
  List.iter (fun (key, value) -> Printf.printf "[%s]: %s\n" key value) item.headers;*)
  Printf.printf "\nLocals: Total count %d\n" (USet.cardinal item.locals);
  USet.iter (fun link -> print_endline (Uri.to_string link)) item.locals;
  Printf.printf "\nGlobals: Total count %d\n" (USet.cardinal item.globals);
  USet.iter (fun link -> print_endline (Uri.to_string link)) item.globals
