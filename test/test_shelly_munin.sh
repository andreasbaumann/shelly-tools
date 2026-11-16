#!/bin/sh
# Integration tests for ../plugins/munin/shelly_ against real devices.
# Exercises it the same way munin-run would: via symlinks named after
# the graph type (optionally with a per-device instance suffix, Munin's
# convention for running the same plugin against multiple hosts), with
# config passed through env vars.
set -u
cd "$(dirname "$0")"
. ./lib.sh

HOSTS="${SHELLY_TEST_HOSTS:-europower1.lan europower2.lan}"
PWDFILE="${SHELLY_TEST_PWDFILE:-$HOME/.config/shelly/credentials}"
PLUGIN_SRC="$(pwd)/../plugins/munin/shelly_"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

for HOST in $HOSTS; do

instance=$(echo "$HOST" | cut -d. -f1)

for g in power voltage energy wifi; do
	ln -s "$PLUGIN_SRC" "$WORKDIR/shelly_${g}_${instance}"
done

export host="$HOST" pwdfile="$PWDFILE"

echo "== shelly_ munin plugin (host: $HOST, instance: $instance) =="

out=$("$WORKDIR/shelly_power_${instance}" autoconf 2>&1); code=$?
assert_exit "autoconf against live device exits 0" 0 "$code"
assert_contains "autoconf reports yes" "$out" "yes"

for g in power voltage energy wifi; do
	out=$("$WORKDIR/shelly_${g}_${instance}" config 2>&1); code=$?
	assert_exit "$g config exits 0" 0 "$code"
	assert_contains "$g config declares a graph_title" "$out" "graph_title"
	assert_contains "$g config declares a graph_category" "$out" "graph_category"
done

out=$("$WORKDIR/shelly_power_${instance}" 2>&1); code=$?
assert_exit "power fetch exits 0" 0 "$code"
for s in 0 1 2 3; do
	assert_contains "power fetch reports socket$s.value" "$out" "socket${s}.value"
done

out=$("$WORKDIR/shelly_voltage_${instance}" 2>&1); code=$?
assert_exit "voltage fetch exits 0" 0 "$code"
assert_contains "voltage fetch reports socket0.value" "$out" "socket0.value"

out=$("$WORKDIR/shelly_energy_${instance}" 2>&1); code=$?
assert_exit "energy fetch exits 0" 0 "$code"
assert_contains "energy fetch reports socket3.value" "$out" "socket3.value"

out=$("$WORKDIR/shelly_wifi_${instance}" 2>&1); code=$?
assert_exit "wifi fetch exits 0" 0 "$code"
assert_contains "wifi fetch reports rssi.value" "$out" "rssi.value"

done

# munin convention: autoconf always exits 0, yes/no is in the output
# (run once, without env.host, so this doesn't depend on which device)
out=$(env -u host "$WORKDIR/shelly_power_${instance}" autoconf 2>&1); code=$?
assert_exit "autoconf without env.host still exits 0" 0 "$code"
assert_contains "autoconf without env.host reports no" "$out" "no ("

summary
