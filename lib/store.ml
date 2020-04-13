open Lwt.Infix
open Parse
open Util

let author = "Erhan Gundogan <erhan.gundogan@gmail.com>"
let c_info fmt = Irmin_unix.info ~author fmt

module Site = struct
  module Site_store = Irmin_unix.Git.FS.KV(Irmin.Contents.String)

  let config repo = Irmin_git.config (Config.pages_irmin_root ^ "/" ^ repo)

  let save address content =
    let repo = get_repo address in
    let key = get_key address in
    Logs.info (fun m -> m "Saving site repo:(%s) to key:(/%s)" repo (String.concat "/" key));
    Site_store.Repo.v (config repo) >>= Site_store.master >>= fun t ->
    Site_store.set_exn t key content ~info:(c_info "saving") >>= fun _ ->
    Lwt.return_unit

  let load address =
    let repo = get_repo address in
    let key = get_key address in
    Site_store.Repo.v (config repo) >>= Site_store.master >>= fun t ->
    Site_store.get t key >>= fun s ->
    Lwt.return s
end

module Data = struct
  let config = Irmin_git.config (Config.details_irmin_root)

  let convert (item: p_t): Graphql.Page.t =
    let convert_set s =
      let l = USet.elements s in
      let rec aux acc = function
      | [] -> acc
      | h :: t -> aux ((Uri.to_string h) :: acc) t in
      List.rev (aux [] l) in
    let uri = Uri.to_string item.uri in
    let redirect =
      if Option.is_some item.redirect
      then Some (Uri.to_string (Option.get item.redirect))
      else None in
    let headers : Graphql.Page.header list = item.headers in
    let locals = convert_set item.locals in
    let globals = convert_set item.globals in
    let secure =
      let final_uri =
        if Option.is_some item.redirect
        then Option.get item.redirect
        else item.uri in
      (Option.get @@ Uri.scheme final_uri) = "https" in
    { uri; redirect; secure; headers; locals; globals }

    let save (address: string) (content: Graphql.Page.t) : unit Lwt.t =
      let repo = get_repo address in
      let base_key = get_key address in
      let key = repo :: base_key in
      Logs.info (fun m -> m "Saving data repo:(%s) to key:(/%s)" repo (String.concat "/" key));
      Graphql.Data_store.Repo.v config >>= Graphql.Data_store.master >>= fun t ->
      Graphql.Data_store.set_exn t key content ~info:(c_info "saving") >>= fun _ ->
      Lwt.return_unit

    let load (address: string) : Graphql.Page.t Lwt.t =
      let repo = get_repo address in
      let base_key = get_key address in
      let key = repo :: base_key in
      Graphql.Data_store.Repo.v config >>= Graphql.Data_store.master >>= fun t ->
      Graphql.Data_store.get t key >>= fun s ->
      Lwt.return s

    let pp (item: Graphql.Page.t) =
      Printf.printf "Address:\n%s\n\n" item.uri;
      if Option.is_some item.redirect
      then Printf.printf "Redirected:\n%s\n\n" (Option.get item.redirect)
      else ();
      print_endline "Secure:";
      Printf.printf "%b\n\n" item.secure;
      Printf.printf "\nLocals: Total count %d\n" (List.length item.locals);
      List.iter (fun link -> print_endline link) item.locals;
      Printf.printf "\nGlobals: Total count %d\n" (List.length item.globals);
      List.iter (fun link -> print_endline link) item.globals
end

let save (p_item: p_t) : unit Lwt.t =
  let data = Data.convert p_item in
  let content = p_item.content in
  let address =
    if Option.is_some data.redirect
    then Option.get data.redirect
    else data.uri in
  Lwt.join [
    Site.save address content;
    Data.save address data
  ]
