source src/on.tcl
source src/assert.tcl
source src/onirule.tcl
source src/irulehttp.tcl
source src/it.tcl
source src/classes.tcl
source src/ip.tcl
source src/global.tcl
namespace import ::testcl::*

before {
  event HTTP_REQUEST
  set_default_pool "/Tenant_Web/App_Web/web_pool"

  datagroup_create allowed_hosts string {
    "api.example.com"
  }

  datagroup_create maintenance_hosts string {
    "maintenance.example.com"
  }

  datagroup_create internal_networks address {
    "10.0.0.0/8"
  }

  datagroup_map uri_to_pool_map_dg string {
    "/api" "/Tenant_Web/App_Web/api_pool"
    "/admin" "/Tenant_Web/App_Web/admin_pool"
  }
}

it "should route api requests to api_pool in sample route_by_uri" {
  on HTTP::uri return "/api/users"
  run examples/irules/route_by_uri.tcl route_by_uri
  verify "effective pool should be api_pool" "api_pool" eq { effective_pool }
}

it "should use default pool for unmatched uri in sample route_by_uri" {
  on HTTP::uri return "/news"
  run examples/irules/route_by_uri.tcl route_by_uri
  verify "effective pool should fall back to default pool" "/Tenant_Web/App_Web/web_pool" eq { effective_pool }
}

it "should route allowed host using host datagroup sample" {
  on HTTP::host return "api.example.com"
  run examples/irules/host_datagroup_routing.tcl host_datagroup_routing
  verify "effective pool should be allowed_pool" "/Tenant_Web/App_Web/allowed_pool" eq { effective_pool }
}

it "should use default pool when host datagroup sample does not match" {
  on HTTP::host return "unknown.example.com"
  run examples/irules/host_datagroup_routing.tcl host_datagroup_routing
  verify "effective pool should stay default pool" "/Tenant_Web/App_Web/web_pool" eq { effective_pool }
}

it "should route mapped uri using uri_to_pool_map sample" {
  on HTTP::uri return "/admin"
  run examples/irules/uri_to_pool_map.tcl uri_to_pool_map
  verify "effective pool should be admin_pool" "/Tenant_Web/App_Web/admin_pool" eq { effective_pool }
}

it "should route internal client using IP::addr sample" {
  set_client_addr "10.1.2.3"
  run examples/irules/access_control_by_ip.tcl access_control_by_ip
  verify "effective pool should be internal_pool" "/Tenant_Web/App_Web/internal_pool" eq { effective_pool }
}

it "should route external client using IP::addr sample" {
  set_client_addr "203.0.113.10"
  run examples/irules/access_control_by_ip.tcl access_control_by_ip
  verify "effective pool should be external_pool" "/Tenant_Web/App_Web/external_pool" eq { effective_pool }
}

it "should route internal network using address datagroup sample" {
  set_client_addr "10.1.2.3"
  run examples/irules/internal_network_datagroup.tcl internal_network_datagroup
  verify "effective pool should be internal_pool" "/Tenant_Web/App_Web/internal_pool" eq { effective_pool }
}

it "should use default pool for external network in address datagroup sample" {
  set_client_addr "172.16.1.1"
  run examples/irules/internal_network_datagroup.tcl internal_network_datagroup
  verify "effective pool should stay default pool" "/Tenant_Web/App_Web/web_pool" eq { effective_pool }
}

it "should route legacy uri to virtual service in sample virtual_routing" {
  on HTTP::uri return "/legacy/users"
  run examples/irules/virtual_routing.tcl virtual_routing
  verify "effective action should be virtual legacy_service" {virtual /Tenant_Web/App_Web/legacy_service} eq { effective_action }
}

it "should use default pool for non legacy uri in sample virtual_routing" {
  on HTTP::uri return "/news"
  run examples/irules/virtual_routing.tcl virtual_routing
  verify "effective pool should stay default pool" "/Tenant_Web/App_Web/web_pool" eq { effective_pool }
}

it "should return maintenance response in sample maintenance_response" {
  on HTTP::host return "maintenance.example.com"
  endstate HTTP::respond 503
  run examples/irules/maintenance_response.tcl maintenance_response
}

it "should use default pool when maintenance host does not match" {
  on HTTP::host return "www.example.com"
  run examples/irules/maintenance_response.tcl maintenance_response
  verify "effective pool should stay default pool" "/Tenant_Web/App_Web/web_pool" eq { effective_pool }
}

stats
