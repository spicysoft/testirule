package provide testcl 1.0.14
package require log
package require cmdline
package require ip

if {![llength [info commands ::testcl::ipv4_equals]]} {
  source [file join [file dirname [info script]] ip.tcl]
}

namespace eval ::testcl {
  namespace export class
  namespace export datagroup_create
  namespace export datagroup_map
  variable classes
  variable class_types
}

# testcl::class --
# 
# stub for class command
#
# See https://devcentral.f5.com/wiki/irules.class.ashx
# 
# class match [<options>] <item> <operator> <class>
# class search [<options>] <class> <operator> <item>
# class lookup <item> <class>
# class element [<options>] <index> <class>
# class type <class>
# class exists <class>
# class size <class>
# class names [-nocase] <class> [<pattern>]
# class get [-nocase] <class> [<pattern>]
# class startsearch <class>
# class nextelement [<options>] <class> <search_id>
# class anymore <class> <search_id>
# class donesearch <class> <search_id>
# 
# For convenience, we also add an extra helper subcommand:
# class configure <class_data>
#
# Example:
# class configure servers {
#   "server1" "192.168.0.1"
#   "server2" "192.168.0.2"
# }
#
# This format bears no resemblance to the formats used in F5
# load balancers, and is simply the easiest to implement

proc ::testcl::datagroup_set {name type entries} {
  variable classes
  variable class_types

  set classes($name) $entries
  set class_types($name) [string tolower $type]
}

proc ::testcl::datagroup_create {name type records} {
  set entries {}
  foreach record $records {
    lappend entries $record ""
  }
  ::testcl::datagroup_set $name $type $entries
}

proc ::testcl::datagroup_map {name type entries} {
  if {[expr {[llength $entries] % 2}] != 0} {
    error "datagroup_map requires an even number of key/value elements"
  }
  ::testcl::datagroup_set $name $type $entries
}

proc ::testcl::class_type_of {classname} {
  variable class_types

  if {[info exists class_types($classname)]} {
    return $class_types($classname)
  }
  return "string"
}

proc ::testcl::class_normalize_operator {operator} {
  set normalized [string map {"-" "_" } [string tolower $operator]]
  switch -- $normalized {
    equals -
    eq {
      return "eq"
    }
    starts_with {
      return "starts_with"
    }
    ends_with {
      return "ends_with"
    }
    contains {
      return "contains"
    }
    default {
      return $normalized
    }
  }
}

proc ::testcl::class_string_matches {value operator record} {
  switch -- [::testcl::class_normalize_operator $operator] {
    eq {
      return [expr {$value eq $record}]
    }
    starts_with {
      return [expr {[string first $record $value] == 0}]
    }
    ends_with {
      set record_length [string length $record]
      if {$record_length == 0} {
        return 1
      }
      set start_index [expr {[string length $value] - $record_length}]
      if {$start_index < 0} {
        return 0
      }
      return [expr {[string range $value $start_index end] eq $record}]
    }
    contains {
      return [expr {[string first $record $value] >= 0}]
    }
    default {
      error "Unsupported class operator '$operator'"
    }
  }
}

proc ::testcl::class_address_matches {value operator record} {
  if {[::testcl::class_normalize_operator $operator] ne "eq"} {
    return 0
  }
  set rc [catch {::testcl::ipv4_equals $value $record} result]
  if {$rc != 0} {
    log::log debug "Unable to compare IP '$value' against '$record': $result"
    return 0
  }
  return $result
}

proc ::testcl::class_record_matches {type value operator record} {
  switch -- [string tolower $type] {
    address -
    ip {
      return [::testcl::class_address_matches $value $operator $record]
    }
    default {
      return [::testcl::class_string_matches $value $operator $record]
    }
  }
}

proc ::testcl::class {cmd args} {
  variable classes
  log::log debug "class $cmd $args invoked"

  set cmdargs [concat class $cmd $args]
  set rc [catch { return [eval testcl::expected $cmdargs] } res]
  if {$rc != 1500} {
    log::log debug "skipping class method evaluation - expectation found for $cmdargs"
    if {$rc < 1000} {
      return $res
    }
    return -code $rc $res
  }
  
  set options {
      {index    "Changes the return value to be the index of the matching class element."}
      {name     "Changes the return value to be the name of the matching class element."}
      {value    "Changes the return value to be the value of the matching class element."}
      {element  "Changes the return value to be a list of the name and value of the matching class element."}
  }
  
  set return_command {
    if {$params(index)} {return $i}
    if {$params(name)} {return $element_name}
    if {$params(value)} {return $element_value}
    if {$params(element)} {return [list $element_name $element_value]}
    return 1
  }
  
  set return_failure_block {
    if {$params(index)} {return -1}
    if {$params(name)} {return ""}
    if {$params(value)} {return ""}
    if {$params(element)} {return ""}
    return 0
  }
  
  array set params [::cmdline::getoptions args $options]
  if {[llength $args] > 0 && [lindex $args 0] eq "--"} {
    set args [lrange $args 1 end]
  }
  switch -- $cmd {
    configure {
      set name [lindex $args 0]
      set value [lindex $args 1]
      ::testcl::datagroup_set $name string $value
    }
    search {
      set classname [lindex $args 0]
      set operator [::testcl::class_normalize_operator [lindex $args 1]]
      set item [lindex $args 2]
      if {[expr ! [info exists classes($classname)]]} $return_failure_block
      set clazz $classes($classname)
      for {set i 0} {$i < [llength $clazz] / 2} {incr i} {
        set element_name [lindex $clazz [expr 2 * $i]]
        set element_value [lindex $clazz [expr 2 * $i + 1]]
        if {[::testcl::class_string_matches $element_name $operator $item]} {
          eval $return_command
        }
      }
      eval $return_failure_block
    }
    match {
      set item [lindex $args 0]
      set operator [::testcl::class_normalize_operator [lindex $args 1]]
      set classname [lindex $args 2]
      if {[expr ! [info exists classes($classname)]]} $return_failure_block
      set class_type [::testcl::class_type_of $classname]
      set clazz $classes($classname)
      for {set i 0} {$i < [llength $clazz] / 2} {incr i} {
        set element_name [lindex $clazz [expr 2 * $i]]
        set element_value [lindex $clazz [expr 2 * $i + 1]]
        if {[::testcl::class_record_matches $class_type $item $operator $element_name]} {
          eval $return_command
        }
      }
      eval $return_failure_block
    }
    lookup {
      set item [lindex $args 0]
      set classname [lindex $args 1]
      return [::testcl::class match -value $item eq $classname]
    }
    element {
      set index [lindex $args 0]
      set classname [lindex $args 1]
      set name [lindex $classes($classname) [expr 2 * $index]]
      set value [lindex $classes($classname) [expr 2 * $index + 1]]
      if {$params(name)} {
        return $name
      }
      if {$params(value)} {
        return $value
      }
      return [list $name $value]
    }
    exists {
      set classname [lindex $args 0]
      return [info exists classes($classname)]
    }
    type {
      set classname [lindex $args 0]
      if {![info exists classes($classname)]} {
        return ""
      }
      return [::testcl::class_type_of $classname]
    }
    size {
      set classname [lindex $args 0]
      if {[expr ! [info exists classes($classname)]]} {
        return 0
      } else {
        return [expr [llength $classes($classname)] / 2]
      }
    }
    names -
    get -
    startsearch -
    nextelement - 
    anymore -
    donesearch {error "Not implemented yet"}
  }
  
}
