#!/bin/sh
# Shared assertion helpers for the test scripts in this directory.
# Intentionally does not use 'set -e': a failed assertion should not
# abort the run, it should just be counted and reported at the end.

TESTS_RUN=0
TESTS_FAILED=0

pass() {
	TESTS_RUN=$((TESTS_RUN + 1))
	echo "  ok   - $1"
}

fail() {
	TESTS_RUN=$((TESTS_RUN + 1))
	TESTS_FAILED=$((TESTS_FAILED + 1))
	echo "  FAIL - $1"
}

# assert_exit <description> <expected_code> <actual_code>
assert_exit() {
	desc="$1"; expected="$2"; actual="$3"
	if test "$actual" -eq "$expected"; then
		pass "$desc (exit $actual)"
	else
		fail "$desc (expected exit $expected, got $actual)"
	fi
}

# assert_contains <description> <haystack> <needle>
assert_contains() {
	desc="$1"; haystack="$2"; needle="$3"
	case "$haystack" in
		*"$needle"*) pass "$desc" ;;
		*) fail "$desc (expected to find '$needle' in: $haystack)" ;;
	esac
}

# assert_not_contains <description> <haystack> <needle>
assert_not_contains() {
	desc="$1"; haystack="$2"; needle="$3"
	case "$haystack" in
		*"$needle"*) fail "$desc (did not expect '$needle' in: $haystack)" ;;
		*) pass "$desc" ;;
	esac
}

summary() {
	echo ""
	echo "$TESTS_RUN tests run, $TESTS_FAILED failed"
	test "$TESTS_FAILED" -eq 0
}
