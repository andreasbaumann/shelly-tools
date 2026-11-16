#!/bin/sh
# Integration tests for ../tools/shelly_switch.sh against real devices.
# Requires network access to the device(s) and a readable, host-keyed
# credentials file (see tools/README.md).
set -u
cd "$(dirname "$0")"
. ./lib.sh

SCRIPT=../tools/shelly_switch.sh
HOSTS="${SHELLY_TEST_HOSTS:-europower1.lan europower2.lan}"
export SHELLY_PWD_FILE="${SHELLY_TEST_PWDFILE:-$HOME/.config/shelly/credentials}"

for HOST in $HOSTS; do

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

# 'led' subcommand - on/off round trip, verifying POWERSTRIP_UI config
# actually changes, then restoring the original mode.
orig_mode=$("$SCRIPT" "$HOST" led status 2>&1 | sed -n 's/.*mode=//p')

out=$("$SCRIPT" "$HOST" led off 2>&1); code=$?
assert_exit "'led off' exits 0" 0 "$code"
assert_contains "'led off' reports mode set to off" "$out" "mode set to off"

out=$("$SCRIPT" "$HOST" led status 2>&1)
assert_contains "'led status' after off shows mode=off" "$out" "mode=off"

out=$("$SCRIPT" "$HOST" led on 2>&1); code=$?
assert_exit "'led on' exits 0" 0 "$code"
assert_contains "'led on' reports mode set to power" "$out" "mode set to power"

out=$("$SCRIPT" "$HOST" led status 2>&1)
assert_contains "'led status' after on shows mode=power" "$out" "mode=power"

# restore the device's original LED mode (only "power" and "off" are
# reachable through the on/off subcommand; leave anything else, e.g.
# "switch", as "power" rather than fail trying to restore it)
if [ "$orig_mode" = "off" ]; then
	"$SCRIPT" "$HOST" led off >/dev/null 2>&1
fi

done

# error handling (no network calls expected to happen for these - run
# once, not per host, since none of this depends on which device is named)
HOST=$(echo "$HOSTS" | cut -d' ' -f1)

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
