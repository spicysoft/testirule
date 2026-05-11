rule access_control_by_ip {

  when HTTP_REQUEST {
    if {[IP::addr [IP::client_addr] equals 10.0.0.0/8]} {
      pool /Tenant_Web/App_Web/internal_pool
    } else {
      pool /Tenant_Web/App_Web/external_pool
    }
  }

}
