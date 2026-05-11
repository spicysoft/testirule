rule effective_route_none {

  when HTTP_REQUEST {
    if {[string first "/api" [HTTP::uri]] == 0} {
      pool /Common/api_pool
    }
  }

}
