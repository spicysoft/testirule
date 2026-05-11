#!/bin/bash

# Set to false in order to provoke warning during package loading
export DISABLE_TESTCL_INTERPRETER_WARNING=true;

function run_test() {
    if [ 'tclsh' == "$1" ] ; then tclsh "$2";
    elif [ 'jtcl' == "$1" ] ; then jtcl "$2";
    else echo "Usage: ./tests.sh [jtcl|tclsh]"; exit 1;
    fi
}

if [ $# -lt 1 ] ; then
    echo "Usage: ./tests.sh [jtcl|tclsh] [test_file ...]"
    exit 1
fi

interpreter="$1"
shift

failures=()

if [ $# -gt 0 ] ; then
    test_files=("$@")
else
    test_files=(test/test_*.tcl)
fi

for file in "${test_files[@]}"
do
    run_test "$interpreter" "$file"
    if [ $? -gt 0 ] ; then
        failures+=($file)
    fi
done

echo "Test Summary"
echo "============"
if [ ${#failures[@]} -gt 0 ] ; then
    echo ${#failures[@]} " tests failed:"
    for failure in ${failures[@]} ; do
        echo "    ${failure}"
    done
    exit ${#failures[@]}
else
    echo "All tests successful"
    exit 0
fi
