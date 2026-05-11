package require -exact testcl 1.0.14
namespace import ::testcl::*

before {
  event HTTP_REQUEST
}

it "should fail when expected pool does not match actual pool" {
  on HTTP::uri return "/healthz"
  on pool default_pool return ""
  endstate pool default_pool
  run examples/minimal_irule.tcl minimal_sample
}

stats
