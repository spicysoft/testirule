rule minimal_sample {

  when HTTP_REQUEST {
    if { [HTTP::uri] eq "/healthz" } {
      pool health_pool
    } else {
      pool default_pool
    }
  }

}
