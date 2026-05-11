source src/on.tcl
source src/assert.tcl
source src/onirule.tcl
source src/irulehttp.tcl
source src/it.tcl
source src/global.tcl
namespace import ::testcl::*

before {
  event HTTP_REQUEST
  set_default_pool "/Common/web_pool"
}

it "should use default pool when nothing is specified" {
  run irules/effective_route_none_irule.tcl effective_route_none
  verify "effective pool should be default pool" "/Common/web_pool" eq { effective_pool }
  verify "effective action should be default pool" {pool /Common/web_pool} eq { effective_action }
}

it "should use default pool when branch does not match explicit pool" {
  on HTTP::uri return "/news"
  run irules/effective_route_none_irule.tcl effective_route_none
  verify "effective pool should stay default pool" "/Common/web_pool" eq { effective_pool }
}

it "should use explicit pool when pool is selected" {
  on HTTP::uri return "/api/users"
  run irules/effective_route_irule.tcl effective_routes
  verify "effective pool should be explicit pool" "/Common/api_pool" eq { effective_pool }
  verify "effective action should be explicit pool" {pool /Common/api_pool} eq { effective_action }
}

it "should use virtual as final action instead of default pool" {
  on HTTP::uri return "/legacy/users"
  run irules/effective_route_irule.tcl effective_routes
  verify "effective pool should be empty for virtual" "" eq { effective_pool }
  verify "effective action should be virtual" {virtual /Common/legacy_vs} eq { effective_action }
}

it "should use redirect as final action instead of default pool" {
  on HTTP::uri return "/redirect"
  run irules/effective_route_irule.tcl effective_routes
  verify "effective action should be redirect" {HTTP::redirect https://example.com/} eq { effective_action }
}

it "should use respond as final action instead of default pool" {
  on HTTP::uri return "/maintenance"
  run irules/effective_route_irule.tcl effective_routes
  verify "effective action should be respond" {HTTP::respond 503} eq { effective_action }
}

it "should leave effective route unset without default pool and explicit action" {
  clear_default_pool
  run irules/effective_route_none_irule.tcl effective_route_none
  verify "effective pool should be empty" "" eq { effective_pool }
  verify "effective action should be empty" "" eq { effective_action }
}

stats
