rule virtual_pool_mix {

  when HTTP_REQUEST {
    pool /Common/default_pool
    virtual /Common/legacy_vs
  }

}
