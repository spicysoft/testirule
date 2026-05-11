rule virtual_bare {

  when HTTP_REQUEST {
    virtual legacy_vs
  }

}
