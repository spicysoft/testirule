rule pool_virtual_mix {

  when HTTP_REQUEST {
    virtual /Common/legacy_vs
    pool /Common/api_pool
  }

}
