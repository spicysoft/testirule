source src/on.tcl
source src/assert.tcl
source src/onirule.tcl
source src/irulehttp.tcl
source src/it.tcl
source src/global.tcl
namespace import ::testcl::*

before {
  event HTTP_REQUEST
}

it "should route to fully qualified virtual server" {
  on HTTP::uri return "/legacy/users"
  endstate virtual /Common/legacy_vs
  run irules/virtual_route_irule.tcl virtual_routes
}

it "should not route to virtual server when condition does not match" {
  on HTTP::uri return "/news"
  on virtual /Common/legacy_vs return ""
  verify "virtual server was not selected" 0 == {catch { run irules/virtual_route_irule.tcl virtual_routes }}
}

it "should treat bare virtual server name as endstate" {
  endstate virtual legacy_vs
  run irules/virtual_bare_irule.tcl virtual_bare
}

it "should keep pool as final action when pool is followed by virtual" {
  endstate pool /Common/default_pool
  run irules/virtual_pool_mix_irule.tcl virtual_pool_mix
}

it "should keep virtual as final action when virtual is followed by pool" {
  endstate virtual /Common/legacy_vs
  run irules/pool_virtual_mix_irule.tcl pool_virtual_mix
}

stats
