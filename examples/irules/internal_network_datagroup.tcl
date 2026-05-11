rule internal_network_datagroup {

  when HTTP_REQUEST {
    if {[class match [IP::client_addr] equals internal_networks]} {
      pool /Tenant_Web/App_Web/internal_pool
    }
  }

}
