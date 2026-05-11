rule effective_routes {

  when HTTP_REQUEST {
    if {[string first "/api" [HTTP::uri]] == 0} {
      pool /Common/api_pool
    } elseif {[string first "/legacy" [HTTP::uri]] == 0} {
      virtual /Common/legacy_vs
    } elseif {[string first "/maintenance" [HTTP::uri]] == 0} {
      HTTP::respond 503 content "maintenance"
    } elseif {[string first "/redirect" [HTTP::uri]] == 0} {
      HTTP::redirect https://example.com/
    }
  }

}
