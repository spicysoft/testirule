source src/on.tcl
source src/assert.tcl
source src/onirule.tcl
source src/irulehttp.tcl
source src/it.tcl
source src/classes.tcl
namespace import ::testcl::*

before {
  event HTTP_REQUEST

  datagroup_create allowed_hosts string {
    "api.example.com"
    "app.example.com"
  }

  datagroup_create allowed_host_suffixes string {
    ".example.com"
  }

  datagroup_create uri_prefixes string {
    "/api"
  }

  datagroup_create contains_terms string {
    "admin"
  }

  datagroup_create internal_networks address {
    "10.0.0.0/8"
    "192.168.0.0/16"
  }

  datagroup_map uri_to_pool_map string {
    "/service" "service_pool"
    "/admin" "admin_lookup_pool"
  }
}

it "should route allowed host using equals match" {
  on HTTP::host return "api.example.com"
  on HTTP::uri return "/"
  on IP::remote_addr return "172.16.1.1"
  endstate pool allowed_pool
  run irules/datagroup_route_irule.tcl datagroup_routes
}

it "should route suffix host using ends-with match" {
  on HTTP::host return "www.example.com"
  on HTTP::uri return "/"
  on IP::remote_addr return "172.16.1.1"
  endstate pool suffix_pool
  run irules/datagroup_route_irule.tcl datagroup_routes
}

it "should route mapped uri using class lookup" {
  on HTTP::host return "unknown.local"
  on HTTP::uri return "/service"
  on IP::remote_addr return "172.16.1.1"
  endstate pool service_pool
  run irules/datagroup_route_irule.tcl datagroup_routes
}

it "should route prefixed uri using starts-with match" {
  on HTTP::host return "unknown.local"
  on HTTP::uri return "/api/users"
  on IP::remote_addr return "172.16.1.1"
  endstate pool prefix_pool
  run irules/datagroup_route_irule.tcl datagroup_routes
}

it "should route admin uri using contains match" {
  on HTTP::host return "unknown.local"
  on HTTP::uri return "/v1/admin/users"
  on IP::remote_addr return "172.16.1.1"
  endstate pool admin_pool
  run irules/datagroup_route_irule.tcl datagroup_routes
}

it "should route internal address using address datagroup" {
  on HTTP::host return "unknown.local"
  on HTTP::uri return "/"
  on IP::remote_addr return "10.1.2.3"
  endstate pool internal_pool
  run irules/datagroup_route_irule.tcl datagroup_routes
}

it "should route unknown request to default pool" {
  on HTTP::host return "unknown.local"
  on HTTP::uri return "/"
  on IP::remote_addr return "172.16.1.1"
  endstate pool default_pool
  run irules/datagroup_route_irule.tcl datagroup_routes
}

stats
