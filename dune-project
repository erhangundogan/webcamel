(lang dune 2.5)
(name webcamel)
(version 0.2.0)
(generate_opam_files true)

(source (github erhangundogan/webcamel))
(license MIT)
(authors "Erhan Gundogan <erhan.gundogan@gmail.com>")
(maintainers "erhan.gundogan@gmail.com")

(package
  (name webcamel)
  (synopsis "Crawler for the web")
  (depends
    (ocaml (>= 4.09.0))
    cmdliner
    cohttp-lwt
    cohttp-lwt-unix
    fmt.tty
    lambdasoup
    logs
    logs.fmt
    lwt
    (irmin (>= 2.2.0))
    irmin-git
    irmin-unix
  ))
