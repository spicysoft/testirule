rule maintenance_response {

  when HTTP_REQUEST {
    if {[class match [HTTP::host] equals maintenance_hosts]} {
      HTTP::respond 503
    }
  }

}
