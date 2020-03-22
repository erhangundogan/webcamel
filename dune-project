(lang dune 2.4)
(name webcamel)
(version 0.1.0)
(generate_opam_files true)

(source (github erhangundogan/webcamel))
(license MIT)
(authors "Erhan Gundogan <erhan.gundogan@gmail.com>")
(maintainers "erhan.gundogan@gmail.com")

(package
  (name webcamel)
  (synopsis "Crawler for the web")
  (depends
    (ocaml (>= 4.08.0))
    lwt
    cohttp-lwt
    cohttp-lwt-unix
    lambdasoup
    logs
  ))
