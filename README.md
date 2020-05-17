# WebCamel

Customizable web crawler. It uses [cohttp](https://github.com/mirage/ocaml-cohttp) client to fetch the addresses. It starts from single URI and goes through other links that have been found in the URI response. It saves data to [irmin](https://github.com/mirage/irmin) git storage which could be viewed by GraphQL client.

This tool is still in development although it could be used to fetch all pages in TLD. There are things missing such as jump to global URI, create queue and handling multiple lwt threads etc. 

There are two executables in the bin folder.

- `main` starts crawling immediately. By default it doesn't jump to other TLDs. The reason is to fetch all pages that belongs to same website.
- `graphql` provides GraphQL server to view details of the data gathered. 

Install
=======

```bash
$ git clone git@github.com:erhangundogan/webcamel.git
$ cd webcamel
$ dune build
```

Run
===

Run the crawler:

```bash
$ ./_build/default/bin/main.exe https://www.example.org
main.exe: [INFO] Fetching: https://www.example.org
main.exe: [INFO] Total 1 URL addresses extracted in 0.976784 secs. locals: 0, globals: 1
main.exe: [INFO] Saving data repo:(example.org) to key:(/example.org/index.html)
main.exe: [INFO] Saving site repo:(example.org) to key:(/index.html)
```

and run irmin graphql server:

```bash
$ ./_build/default/bin/graphql.exe
Visit GraphiQL @ http://localhost:9876/graphql
```

Open your browser and navigate to http://localhost:9876/graphql and run this graphql query:

```graphql
{
  master {
    tree {
      get_contents(key:"/example.org/index.html") {
        key
        value {
          uri
          redirect
          secure
          locals
          globals
          headers {
            key
            value
          }
        }
      }
    }
  }
}
```

![graphql-query-result](https://github.com/erhangundogan/webcamel/blob/master/gql.png)

Internal Structure
==================

irmin uses git-fs mode to save data into the `/tmp` folder so they would be disposed. If you want to keep data change it from the config.ml

There are 2 irmin stores. One for page sources and one for the page details. The one above shows page details.

## /tmp/irmin/sites

git repo per TLD. You can see the repos if you change the directory.
```bash
$ cd /tmp/irmin/sites
$ ls
example.org/ x.com/

$ irmin list -s git --root /tmp/irmin/sites/example.org /
FILE index.html
```

## /tmp/irmin/data

all top level domains included under the same git repo. There are 6 fields stored from the request aside HTML source code.

- `uri` (string) Requested URI
- `redirect` (string option) Eventual URI if there is a redirection
- `secure` (bool) Is the URI provides secure connection
- `locals` (string list) Addresses extracted from the page that belongs to TLD. This is Uri.t Set for the absolute URIs.
- `globals` (string list) Similar to `locals` but these URIs belong to other TLDs.
- `header` (header list) Key/Value list for the received HTTP Headers. 

```
$ irmin list -s git --root /tmp/irmin/data /
DIR  example.org
DIR  x.com

$ irmin list -s git --root /tmp/irmin/data /example.org
FILE index.html

$ irmin get -s git --root /tmp/irmin/data /example.org/index.html
{
  "uri": "https://www.example.org",
  "secure": 1,
  "headers": [
    {
      "key": "accept-ranges",
      "value": "bytes"
    },
    {
      "key": "age",
      "value": "288506"
    },
    {
      "key": "cache-control",
      "value": "max-age=604800"
    },
    {
      "key": "content-length",
      "value": "1256"
    },
    {
      "key": "content-type",
      "value": "text/html; charset=UTF-8"
    },
    {
      "key": "date",
      "value": "Sun, 17 May 2020 12:32:49 GMT"
    },
    {
      "key": "etag",
      "value": "\"3147526947\""
    },
    {
      "key": "expires",
      "value": "Sun, 24 May 2020 12:32:49 GMT"
    },
    {
      "key": "last-modified",
      "value": "Thu, 17 Oct 2019 07:18:26 GMT"
    },
    {
      "key": "server",
      "value": "ECS (nyb/1D1F)"
    },
    {
      "key": "vary",
      "value": "Accept-Encoding"
    },
    {
      "key": "x-cache",
      "value": "HIT"
    }
  ],
  "globals": [
    "https://www.iana.org/domains/example"
  ]
}
```

