#!/bin/sh
# Integration tests for ../plugins/munin/shelly_ against a real device.
# Exercises it the same way munin-run would: via symlinks named after
# the graph type, with config passed through env vars.
set -u
cd "$(dirname "$0")"
. ./lib.sh

HOST="${SHELLY_TEST_HOST:-europower1.lan}"
PWDFILE="${SHELLY_TEST_PWDFILE:-$HOME/.config/shelly/credentials}"
PLUGIN_SRC="$(pwd)/../plugins/munin/shelly_"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

for g in power voltage energy wifi; do
	ln -s "$PLUGIN_SRC" "$WORKDIR/shelly_$g"
done

export host="$HOST" pwdfile="$PWDFILE"

echo "== shelly_ munin plugin (host: $HOST) =="

out=$("$WORKDIR/shelly_power" autoconf 2>&1); code=$?
assert_exit "autoconf against live device exits 0" 0 "$code"
assert_contains "autoconf reports yes" "$out" "yes"

for g in power voltage energy wifi; do
	out=$("$WORKDIR/shelly_$g" config 2>&1); code=$?
	assert_exit "$g config exits 0" 0 "$code"
	assert_contains "$g config declares a graph_title" "$out" "graph_title"
	assert_contains "$g config declares a graph_category" "$out" "graph_category"
done

out=$("$WORKDIR/shelly_power" 2>&1); code=$?
assert_exit "power fetch exits 0" 0 "$code"
for s in 0 1 2 3; do
	assert_contains "power fetch reports socket$s.value" "$out" "socket${s}.value"
done

out=$("$WORKDIR/shelly_voltage" 2>&1); code=$?
assert_exit "voltage fetch exits 0" 0 "$code"
assert_contains "voltage fetch reports socket0.value" "$out" "socket0.value"

out=$("$WORKDIR/shelly_energy" 2>&1); code=$?
assert_exit "energy fetch exits 0" 0 "$code"
assert_contains "energy fetch reports socket3.value" "$out" "socket3.value"

out=$("$WORKDIR/shelly_wifi" 2>&1); code=$?
assert_exit "wifi fetch exits 0" 0 "$code"
assert_contains "wifi fetch reports rssi.value" "$out" "rssi.value"

# munin convention: autoconf always exits 0, yes/no is in the output
out=$(env -u host "$WORKDIR/shelly_power" autoconf 2>&1); code=$?
assert_exit "autoconf without env.host still exits 0" 0 "$code"
assert_contains "autoconf without env.host reports no" "$out" "no ("

summary
