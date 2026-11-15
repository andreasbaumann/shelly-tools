#!/bin/sh
# Runs every test_*.sh in this directory against a real device and
# reports a combined pass/fail summary.
#
# Override device/credentials with:
#   SHELLY_TEST_HOST=europower1.lan SHELLY_TEST_PWDFILE=~/.config/shelly/credentials ./run_all.sh
set -u
cd "$(dirname "$0")"

overall=0
for t in test_*.sh; do
	echo ""
	echo "### $t ###"
	sh "./$t"
	if test $? -ne 0; then
		overall=1
	fi
done

echo ""
if test "$overall" -eq 0; then
	echo "ALL TESTS PASSED"
else
	echo "SOME TESTS FAILED"
fi
exit "$overall"
