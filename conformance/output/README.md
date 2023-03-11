./conformance_test_runner --failure_list failure_list_zig.txt     zig-out/bin/conformance 2>&1 | grep -e "Required" -e "Recommended" > output/err.txt
