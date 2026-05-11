package require -exact testcl 1.0.14
namespace import ::testcl::*

before {
  event HTTP_REQUEST
}

it "should route health endpoint to health_pool" {
  on HTTP::uri return "/healthz"
  on pool default_pool return ""
  endstate pool health_pool
  run examples/minimal_irule.tcl minimal_sample
}

it "should route other requests to default_pool" {
  on HTTP::uri return "/"
  on pool health_pool return ""
  endstate pool default_pool
  run examples/minimal_irule.tcl minimal_sample
}

stats
