source src/on.tcl
source src/assert.tcl
source src/onirule.tcl
source src/irulehttp.tcl
source src/it.tcl
source src/ip.tcl
namespace import ::testcl::*

before {
  event HTTP_REQUEST
}

it "should route internal client to internal_pool" {
  set_client_addr "10.1.2.3"
  endstate pool internal_pool
  run irules/ip_route_irule.tcl ip_routes
}

it "should route external client to external_pool" {
  set_client_addr "203.0.113.10"
  endstate pool external_pool
  run irules/ip_route_irule.tcl ip_routes
}

stats
