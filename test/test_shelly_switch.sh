#!/bin/sh
# Integration tests for ../tools/shelly_switch.sh against a real device.
# Requires network access to the device and a readable credentials file.
set -u
cd "$(dirname "$0")"
. ./lib.sh

SCRIPT=../tools/shelly_switch.sh
HOST="${SHELLY_TEST_HOST:-europower1.lan}"
export SHELLY_PWD_FILE="${SHELLY_TEST_PWDFILE:-$HOME/.config/shelly/credentials}"

echo "== shelly_switch.sh (host: $HOST) =="

for s in 0 1 2 3; do
	out=$("$SCRIPT" "$HOST" "$s" status 2>&1); code=$?
	assert_exit "status socket $s exits 0" 0 "$code"
	assert_contains "status socket $s mentions socket id and host" "$out" "Socket $s on $HOST"
	assert_contains "status socket $s reports output=" "$out" "output="
done

# on/off round trip on socket 3 - verifies the RPC call actually
# changes device state, not just that the script runs.
out=$("$SCRIPT" "$HOST" 3 off 2>&1); code=$?
assert_exit "off socket 3 exits 0" 0 "$code"
assert_contains "off socket 3 reports turned off" "$out" "turned off"

out=$("$SCRIPT" "$HOST" 3 status 2>&1)
assert_contains "status after off shows output=false" "$out" "output=false"

out=$("$SCRIPT" "$HOST" 3 on 2>&1); code=$?
assert_exit "on socket 3 exits 0" 0 "$code"
assert_contains "on socket 3 reports turned on" "$out" "turned on"

out=$("$SCRIPT" "$HOST" 3 status 2>&1)
assert_contains "status after on shows output=true" "$out" "output=true"

# 'all' shortcut
out=$("$SCRIPT" "$HOST" all status 2>&1); code=$?
assert_exit "'all status' exits 0" 0 "$code"
for s in 0 1 2 3; do
	assert_contains "'all status' includes socket $s" "$out" "Socket $s on $HOST"
done

# error handling (no network calls expected to happen for these)
out=$("$SCRIPT" "$HOST" 9 status 2>&1); code=$?
assert_exit "invalid socket number (9) is rejected" 1 "$code"
assert_contains "invalid socket number reports an error" "$out" "Error"

out=$("$SCRIPT" "$HOST" 3 bogus 2>&1); code=$?
assert_exit "invalid state ('bogus') is rejected" 1 "$code"
assert_contains "invalid state reports an error" "$out" "Error"

out=$("$SCRIPT" "$HOST" 3 2>&1); code=$?
assert_exit "missing 3rd argument is rejected" 1 "$code"
assert_contains "missing argument shows usage" "$out" "Usage"

summary
