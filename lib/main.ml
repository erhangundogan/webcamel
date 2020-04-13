open Lwt.Infix

module USet = Parse.USet

let crawl address =
  let set = USet.empty in
  let current = USet.add address set in
  let rec aux all used = match USet.compare all used with
  | 0 -> Lwt.return_unit
  | _ ->
    let diff = USet.diff all used in
    let item = USet.min_elt diff in
    (Parse.start item) >>= fun result ->
      Store.save result >>= fun _ ->
        aux (USet.union all result.locals) (USet.add item used) in
    aux current USet.empty

let recall address =
  Store.Data.load (Uri.to_string address) >|= fun store_item ->
    Store.Data.pp store_item
