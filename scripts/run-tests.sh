#!/usr/bin/env bash

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

export DISABLE_TESTCL_INTERPRETER_WARNING=true
export TCLLIBPATH="${repo_root}${TCLLIBPATH:+ ${TCLLIBPATH}}"

if [ "$#" -gt 0 ]; then
  case "$1" in
    python3)
      echo "Running requested command: $*"
      exec "$@"
      ;;
    test/*)
      echo "Running requested test target with tclsh: $1"
      exec bash "$repo_root/tests.sh" tclsh "$@"
      ;;
    *)
      echo "Running requested test target with tclsh: $1"
      exec tclsh "$repo_root/$1"
      ;;
  esac
fi

if compgen -G "$repo_root/test/test_*.tcl" > /dev/null; then
  echo "Running existing TesTcl test suite with tclsh"
  bash "$repo_root/tests.sh" tclsh
fi

if find "$repo_root/tests" -name "test_*.py" -print -quit | grep -q .; then
  echo "Running Python test suite"
  python3 -m unittest discover -s "$repo_root/tests" -p "test_*.py"
  exit 0
fi

echo "No existing test suite found, running minimal example test"
tclsh "$repo_root/examples/test_minimal_irule.tcl"
