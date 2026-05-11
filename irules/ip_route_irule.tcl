rule ip_routes {

  when HTTP_REQUEST {
    if {[IP::addr [IP::client_addr] equals 10.0.0.0/8]} {
      pool internal_pool
    } else {
      pool external_pool
    }
  }

}
