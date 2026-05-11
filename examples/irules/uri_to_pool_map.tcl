rule uri_to_pool_map {

  when HTTP_REQUEST {
    set target_pool [class lookup [HTTP::uri] uri_to_pool_map_dg]
    if {$target_pool ne ""} {
      pool $target_pool
    }
  }

}
