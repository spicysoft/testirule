package require -exact testcl 1.0.14
namespace import ::testcl::*

# Comment out to suppress logging
#log::lvSuppressLE info 0

assertNumberEquals [::testcl::IP::addr "10.1.2.3" equals "10.1.2.3"] 1
assertNumberEquals [::testcl::IP::addr "10.1.2.3" equals "10.1.2.4"] 0
assertNumberEquals [::testcl::IP::addr "10.1.2.3" equals "10.0.0.0/8"] 1
assertNumberEquals [::testcl::IP::addr "10.1.2.3" equals "10.1.2.0/24"] 1
assertNumberEquals [::testcl::IP::addr "10.1.2.3" equals "10.1.3.0/24"] 0
assertNumberEquals [::testcl::IP::addr "10.0.0.0" equals "10.0.0.0/8"] 1
assertNumberEquals [::testcl::IP::addr "10.255.255.255" equals "10.0.0.0/8"] 1
assertNumberEquals [::testcl::IP::addr "11.0.0.0" equals "10.0.0.0/8"] 0
assertNumberEquals [::testcl::IP::addr "10.1.2.3" == "10.0.0.0/8"] 1

set invalid_ip_rc [catch {::testcl::IP::addr "bad-ip" equals "10.0.0.0/8"} invalid_ip_msg]
assertNumberEquals $invalid_ip_rc 1
assertStringEquals "invalid IP address: bad-ip" $invalid_ip_msg

set invalid_cidr_rc [catch {::testcl::IP::addr "10.1.2.3" equals "10.0.0.0/99"} invalid_cidr_msg]
assertNumberEquals $invalid_cidr_rc 1
assertStringEquals "invalid CIDR: 10.0.0.0/99" $invalid_cidr_msg

set_client_addr "10.1.2.3"
assertStringEquals [IP::client_addr] "10.1.2.3"
assertStringEquals [IP::remote_addr] "10.1.2.3"
