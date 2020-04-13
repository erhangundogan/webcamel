let pages_irmin_root = "/tmp/irmin/sites"
let details_irmin_root = "/tmp/irmin/data"

type graphql_server_type = {
  host: string;
  port: int
}
let graphql_server = {
  host = "localhost";
  port = 9876
}
let web_client_headers = [
  ("user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:61.0) Gecko/20100101 Firefox/74.0");
  ("accept", "text/html");
  ("accept-language", "en-US,en;q=0.5")
]
