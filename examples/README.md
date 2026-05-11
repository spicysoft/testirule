This folder contains examples demonstrating how to write TesTcl/TestiRule tests.

Main sample areas:

- `irules/`: successful sample iRules that are exercised by tests and AS3/iRule validation
- `broken-irules/`: failure samples used to confirm non-zero validation exits
- `as3/`: AS3 declaration and extracted context JSON for the sample application

The samples show how to combine:

- `pool` and default pool fallback
- `class match` and `class lookup`
- `IP::addr` and address Data Groups
- `virtual`
- `HTTP::respond`
- AS3 context extraction
- AS3/iRule reference validation
