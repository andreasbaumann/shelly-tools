#!/bin/sh
# Integration tests for ../plugins/nagios/check_shelly against a real device.
#
# Threshold tests rely on socket 3 carrying its observed small (~5W)
# continuous load and mains sitting near 230V - that's how this specific
# device/socket behaves, not a property of the plugin, so these may need
# adjusting if the test hardware setup changes.
set -u
cd "$(dirname "$0")"
. ./lib.sh

SCRIPT=../plugins/nagios/check_shelly
SWITCH=../tools/shelly_switch.sh
HOST="${SHELLY_TEST_HOST:-europower1.lan}"
PWDFILE="${SHELLY_TEST_PWDFILE:-$HOME/.config/shelly/credentials}"

echo "== check_shelly (host: $HOST) =="

# make sure socket 3 is on and drawing its usual small load before the
# power-threshold tests below
"$SWITCH" "$HOST" 3 on >/dev/null 2>&1

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=power 2>&1); code=$?
assert_exit "power mode with no thresholds is OK" 0 "$code"
assert_contains "power output reports all 4 sockets" "$out" "socket3="

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=power --warn=1 --crit=1000 2>&1); code=$?
assert_exit "power mode: socket3 load (~5W) above warn=1 -> WARNING" 1 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=power --warn=0 --crit=0.001 2>&1); code=$?
assert_exit "power mode: socket3 load above crit=0.001 -> CRITICAL" 2 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=voltage 2>&1); code=$?
assert_exit "voltage mode with default thresholds is OK" 0 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=voltage --warn-high=229 2>&1); code=$?
assert_exit "voltage mode: mains (~230V) above warn-high=229 -> WARNING" 1 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=voltage --crit-high=229 2>&1); code=$?
assert_exit "voltage mode: mains (~230V) above crit-high=229 -> CRITICAL" 2 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=wifi 2>&1); code=$?
assert_exit "wifi mode with default thresholds is OK" 0 "$code"
assert_contains "wifi output reports rssi" "$out" "rssi="

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=wifi --warn=-10 --crit=-20 2>&1); code=$?
assert_exit "wifi mode: strong signal below crit=-20 -> CRITICAL" 2 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=health 2>&1); code=$?
assert_exit "health mode is OK" 0 "$code"
assert_contains "health output reports restart_required" "$out" "restart_required="

# state mode: socket 3 is on (ensured above); pick another socket and
# flip it off so we can exercise both the matching and mismatching path
"$SWITCH" "$HOST" 1 off >/dev/null 2>&1

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=state --expect-on=3 --expect-off=1 2>&1); code=$?
assert_exit "state mode: socket3 on + socket1 off both match -> OK" 0 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=state --expect-on=1 2>&1); code=$?
assert_exit "state mode: socket1 expected on but is off -> CRITICAL" 2 "$code"
assert_contains "state mismatch output flags the socket" "$out" "expected on"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=state --expect-off=3 2>&1); code=$?
assert_exit "state mode: socket3 expected off but is on -> CRITICAL" 2 "$code"
assert_contains "state mismatch output flags the socket" "$out" "expected off"

# WARN-tier severity: same mismatches, but only WARNING, not CRITICAL
out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=state --expect-on-warn=1 2>&1); code=$?
assert_exit "state mode: --expect-on-warn mismatch -> WARNING (not CRITICAL)" 1 "$code"
assert_contains "WARN-tier mismatch is labelled WARN" "$out" "WARN"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=state --expect-off-warn=3 2>&1); code=$?
assert_exit "state mode: --expect-off-warn mismatch -> WARNING (not CRITICAL)" 1 "$code"
assert_contains "WARN-tier mismatch is labelled WARN" "$out" "WARN"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=state --expect-on-warn=3 --expect-off-warn=1 2>&1); code=$?
assert_exit "state mode: --expect-on-warn/--expect-off-warn both match -> OK" 0 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=state 2>&1); code=$?
assert_exit "state mode without any --expect-* flag -> UNKNOWN" 3 "$code"

# --expect-on/--expect-off must also fold into --mode=power (and
# --mode=voltage), not just be silently ignored outside --mode=state
out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=power --expect-on=3 --expect-off=1 2>&1); code=$?
assert_exit "power mode: expect-on/off match (socket3 on, socket1 off) -> OK" 0 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=power --expect-on=1 2>&1); code=$?
assert_exit "power mode: expect-on mismatch (socket1 off) -> CRITICAL" 2 "$code"
assert_contains "power mode mismatch is flagged in the socket text" "$out" "state-CRIT"

"$SWITCH" "$HOST" 1 on >/dev/null 2>&1

# argument / connectivity error handling
out=$("$SCRIPT" --mode=power 2>&1); code=$?
assert_exit "missing --host -> UNKNOWN" 3 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" 2>&1); code=$?
assert_exit "missing --mode -> UNKNOWN" 3 "$code"

out=$("$SCRIPT" --host="$HOST" --pwdfile="$PWDFILE" --mode=bogus 2>&1); code=$?
assert_exit "unknown mode -> UNKNOWN" 3 "$code"

out=$("$SCRIPT" --host=192.168.1.254 --pwdfile="$PWDFILE" --mode=wifi --timeout=3 2>&1); code=$?
assert_exit "unreachable host -> UNKNOWN" 3 "$code"

summary
