rule datagroup_routes {

  when HTTP_REQUEST {
    set host [HTTP::host]
    set uri [HTTP::uri]
    set client_ip [IP::remote_addr]

    if {[class match $host equals allowed_hosts]} {
      pool allowed_pool
    } elseif {[class match $host ends-with allowed_host_suffixes]} {
      pool suffix_pool
    } elseif {[class lookup $uri uri_to_pool_map] ne ""} {
      pool [class lookup $uri uri_to_pool_map]
    } elseif {[class match $uri starts-with uri_prefixes]} {
      pool prefix_pool
    } elseif {[class match $uri contains contains_terms]} {
      pool admin_pool
    } elseif {[class match $client_ip equals internal_networks]} {
      pool internal_pool
    } else {
      pool default_pool
    }
  }

}
