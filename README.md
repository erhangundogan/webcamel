# WebCamel

Crawler for the web.

Install
=======

```bash
$ git clone git@github.com:erhangundogan/webcamel.git
$ cd webcamel
$ dune build
```

Structure
=========

## /sites

git repo per top level domain:
```
$ ls
/example.org
/edition.cnn.com
/localhost

$ cd localhost
$ irmin list /
DIR  baz
DIR  foo
FILE index.html
```

## /data

all top level domains included
```
$ irmin list /
DIR  edition.cnn.com
DIR  example.org
DIR  localhost

$ irmin list /localhost
DIR  baz
DIR  foo
FILE index.html

$ irmin get /localhost/index.html
{
  "uri": "http://localhost:8000/",
  "secure": 0,
  "headers": [
    {
      "key": "access-control-allow-headers",
      "value": "Origin, X-Requested-With, Content-Type, Accept"
    },
    {
      "key": "access-control-allow-origin",
      "value": "*"
    },
    {
      "key": "connection",
      "value": "keep-alive"
    },
    {
      "key": "content-length",
      "value": "70"
    },
    {
      "key": "content-type",
      "value": "text/html; charset=utf-8"
    },
    {
      "key": "date",
      "value": "Mon, 13 Apr 2020 11:38:01 GMT"
    },
    {
      "key": "etag",
      "value": "W/\"46-tscUFzqcEDynW2eG488SxkcI1AA\""
    },
    {
      "key": "x-powered-by",
      "value": "Express"
    }
  ],
  "locals": [
    "http://localhost:8000/baz",
    "http://localhost:8000/foo"
  ]
}
```

Usage
=====

## Client

```bash
./_build/default/bin/main.exe https://www.wired.com

main.exe: [INFO] Fetching: https://www.wired.com
main.exe: [INFO] Total 105 URL addresses extracted in 0.720915 secs. locals: 92, globals: 13
main.exe: [INFO] Saving data repo:(wired.com) to key:(/wired.com/index.html)
main.exe: [INFO] Saving site repo:(wired.com) to key:(/index.html)
```

## GraphQL

```bash
./_build/default/bin/graphql.exe
```
