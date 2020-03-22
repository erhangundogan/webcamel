open Lwt.Infix
open Webcamel

let () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level @@ Some Logs.Info;
  Logs.set_reporter (Logs_fmt.reporter ());
  let address = Sys.argv.(1) in
  Lwt_main.run (start address >|= fun r -> pp r)
