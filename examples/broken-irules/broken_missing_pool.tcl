rule broken_missing_pool {

  when HTTP_REQUEST {
    pool /Tenant_Web/App_Web/missing_pool
  }

}
