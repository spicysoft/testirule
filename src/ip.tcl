package provide testcl 1.0.14
package require log
package require ip

namespace eval ::testcl::IP {
  namespace export addr
  namespace export client_addr
  namespace export remote_addr
  # namespace export IP::hops
  # namespace export IP::idle_timeout
  # namespace export IP::intelligence
  # namespace export IP::local_addr
  # namespace export IP::protocol
  # namespace export IP::server_addr
  # namespace export IP::stats
  # namespace export IP::tos
  # namespace export IP::ttl
  # namespace export IP::version
  # namespace export IP::reputation
}

namespace eval ::testcl {
  namespace export set_client_addr
  variable client_addr
}

namespace eval ::IP {}

proc ::testcl::ipv4_validate {value} {
    if {![regexp {^(\d{1,3}\.){3}\d{1,3}$} $value]} {
        error "invalid IP address: $value"
    }
    foreach octet [split $value .] {
        if {$octet < 0 || $octet > 255} {
            error "invalid IP address: $value"
        }
    }
    return $value
}

proc ::testcl::cidr_validate {value} {
    if {![regexp {^([^/]+)/(\d{1,2})$} $value -> base prefix]} {
        error "invalid CIDR: $value"
    }
    ::testcl::ipv4_validate $base
    if {$prefix < 0 || $prefix > 32} {
        error "invalid CIDR: $value"
    }
    return $value
}

proc ::testcl::ipv4_to_int {value} {
    ::testcl::ipv4_validate $value
    lassign [split $value .] a b c d
    return [expr {($a << 24) | ($b << 16) | ($c << 8) | $d}]
}

proc ::testcl::cidr_mask_to_int {prefix} {
    if {$prefix < 0 || $prefix > 32} {
        error "invalid CIDR: /$prefix"
    }
    if {$prefix == 0} {
        return 0
    }
    return [expr {((0xffffffff << (32 - $prefix)) & 0xffffffff)}]
}

proc ::testcl::ipv4_target_parse {value} {
    if {[string first "/" $value] >= 0} {
        ::testcl::cidr_validate $value
        regexp {^([^/]+)/(\d{1,2})$} $value -> base prefix
        return [list [::testcl::ipv4_to_int $base] [::testcl::cidr_mask_to_int $prefix]]
    }

    ::testcl::ipv4_validate $value
    return [list [::testcl::ipv4_to_int $value] 0xffffffff]
}

proc ::testcl::ipv4_equals {ip target} {
    set ip_int [::testcl::ipv4_to_int $ip]
    lassign [::testcl::ipv4_target_parse $target] target_int mask
    return [expr {(($ip_int & $mask) == ($target_int & $mask)) ? 1 : 0}]
}

proc ::testcl::set_client_addr {value} {
    variable client_addr
    set client_addr [::testcl::ipv4_validate $value]
}

# testcl::IP::addr --
#
# stub for the F5 function IP::addr - Performs comparison of IP address/subnet/supernet to IP address/subnet/supernet. or parses 4 binary bytes into an IPv4 dotted quad address
#
# IP::addr <addr1>[/<mask>] equals <addr2>[/<mask>]
#
# (Not yet implemented)
# IP::addr parse [-swap] <binary field> [<offset>]
# IP::addr <addr1> mask <mask>
# IP::addr parse [-ipv6|-ipv4 [-swap]] <bytearray> [<offset>]
#
proc ::testcl::IP::addr { ip1 op ip2 } {
    log::log debug "testcl::IP::addr $ip1 $op $ip2 invoked"
    if {$op eq "equals" || $op eq "=="} {
        return [::testcl::ipv4_equals $ip1 $ip2]
    }
    error "unsupported IP::addr operator: $op"
}

proc ::testcl::IP::client_addr {} {
    log::log debug "testcl::IP::client_addr invoked"
    set cmdargs [list IP::client_addr]
    set rc [catch { return [eval testcl::expected $cmdargs] } res]
    if {$rc != 1500} {
        log::log debug "skipping IP::client_addr evaluation - expectation found"
        if {$rc < 1000} {
            return $res
        }
        return -code $rc $res
    }

    variable ::testcl::client_addr
    if {[info exists ::testcl::client_addr]} {
        return $::testcl::client_addr
    }
    error "IP::client_addr is not set"
}

proc ::testcl::IP::remote_addr {} {
    log::log debug "testcl::IP::remote_addr invoked"
    set cmdargs [list IP::remote_addr]
    set rc [catch { return [eval testcl::expected $cmdargs] } res]
    if {$rc != 1500} {
        log::log debug "skipping IP::remote_addr evaluation - expectation found"
        if {$rc < 1000} {
            return $res
        }
        return -code $rc $res
    }

    variable ::testcl::client_addr
    if {[info exists ::testcl::client_addr]} {
        return $::testcl::client_addr
    }
    error "IP::remote_addr is not set"
}

proc ::IP::addr {ip1 op ip2} {
    return [::testcl::IP::addr $ip1 $op $ip2]
}

proc ::IP::client_addr {} {
    return [::testcl::IP::client_addr]
}

proc ::IP::remote_addr {} {
    return [::testcl::IP::remote_addr]
}
