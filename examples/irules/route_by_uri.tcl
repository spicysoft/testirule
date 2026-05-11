rule route_by_uri {

  when HTTP_REQUEST {
    if {[string first "/api" [HTTP::uri]] == 0} {
      pool api_pool
    }
  }

}
