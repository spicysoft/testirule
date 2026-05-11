rule virtual_routes {

  when HTTP_REQUEST {
    if {[string first "/legacy" [HTTP::uri]] == 0} {
      virtual /Common/legacy_vs
    }
  }

}
