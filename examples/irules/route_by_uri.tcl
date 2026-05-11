when HTTP_REQUEST {
  if {[class match [HTTP::host] equals allowed_hosts]} {
    pool api_pool
  } else {
    pool web_pool
  }
}
