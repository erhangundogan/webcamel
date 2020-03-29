let split char str = str
  |> String.split_on_char char
  |> List.filter (fun s -> s <> "")

let strip_www uri =
  let host = Option.get (Uri.host uri) in
  let re = Str.regexp "www.?\\." in
  Str.replace_first re "" host

let get_repo address =
  strip_www (Uri.of_string address)

let get_key address =
  let has_page path =
    let re = Str.regexp "^.*\\.\\(html?\\|php\\|aspx?\\|jsp\\)$" in
    Str.string_match re path 0 in
  let path = Uri.(path (of_string address)) in
  let spath = split '/' path in
  if has_page path then spath else spath @ ["index.html"]
