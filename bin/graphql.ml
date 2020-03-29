open Webcamel

let () =
  Lwt_main.run (Graphql.init ())
