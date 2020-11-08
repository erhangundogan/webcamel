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
  ("user-agent", "Webcamel");
  ("accept", "text/html");
  ("accept-language", "en-US,en;q=0.5")
]
let uri_schemes_supported = ["http"; "https"]
