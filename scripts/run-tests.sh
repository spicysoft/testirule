#!/usr/bin/env bash

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

export DISABLE_TESTCL_INTERPRETER_WARNING=true
export TCLLIBPATH="${repo_root}${TCLLIBPATH:+ ${TCLLIBPATH}}"

if compgen -G "$repo_root/test/test_*.tcl" > /dev/null; then
  echo "Running existing TesTcl test suite with tclsh"
  exec bash "$repo_root/tests.sh" tclsh
fi

echo "No existing test suite found, running minimal example test"
exec tclsh "$repo_root/examples/test_minimal_irule.tcl"
