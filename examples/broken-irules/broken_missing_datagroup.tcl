rule broken_missing_datagroup {

  when HTTP_REQUEST {
    if {[class match [HTTP::host] equals missing_hosts]} {
      pool /Tenant_Web/App_Web/web_pool
    }
  }

}
