rule virtual_routing {

  when HTTP_REQUEST {
    if {[string first "/legacy" [HTTP::uri]] == 0} {
      virtual /Tenant_Web/App_Web/legacy_service
    }
  }

}
