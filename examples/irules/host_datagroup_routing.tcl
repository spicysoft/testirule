rule host_datagroup_routing {

  when HTTP_REQUEST {
    if {[class match [HTTP::host] equals allowed_hosts]} {
      pool /Tenant_Web/App_Web/allowed_pool
    }
  }

}
