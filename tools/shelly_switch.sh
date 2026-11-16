#!/usr/bin/env bash
# Control or query a socket, or the LED indication, on a Shelly Power Strip
# Gen4 via RPC.
set -euo pipefail

usage() {
    echo "Usage: $0 <host> <socket 0-3|all|led> <on|off|status>" >&2
    echo "       $0 <host> led brightness <0-100|status>" >&2
    echo "Example: $0 europower1.lan 3 on" >&2
    echo "Example: $0 europower1.lan all status" >&2
    echo "Example: $0 europower1.lan led off" >&2
    echo "Example: $0 europower1.lan led brightness 80" >&2
    echo "Example: $0 europower1.lan led brightness status" >&2
    exit 1
}

[[ $# -eq 3 || $# -eq 4 ]] || usage

host="$1"
socket="$2"
state="$3"
value="${4:-}"

[[ "$socket" =~ ^[0-3]$ || "$socket" == "all" || "$socket" == "led" ]] || { echo "Error: socket must be 0-3, 'all', or 'led'" >&2; exit 1; }

case "$state" in
    on|off|status|get)
        [[ -z "$value" ]] || usage
        ;;
    brightness)
        [[ "$socket" == "led" ]] || { echo "Error: 'brightness' is only valid for 'led'" >&2; exit 1; }
        [[ -n "$value" ]] || usage
        [[ "$value" == "status" || "$value" == "get" || ( "$value" =~ ^[0-9]+$ && "$value" -ge 0 && "$value" -le 100 ) ]] \
            || { echo "Error: brightness value must be 0-100 or 'status'" >&2; exit 1; }
        ;;
    *) echo "Error: state must be 'on', 'off', 'status', or 'brightness' (led only)" >&2; exit 1 ;;
esac

pwd_file="${SHELLY_PWD_FILE:-$HOME/.config/shelly/credentials}"
[[ -r "$pwd_file" ]] || { echo "Error: credentials file not found: $pwd_file" >&2; exit 1; }

creds=""
while IFS= read -r line; do
    case "$line" in
        "${host}:"*) creds="${line#*:}"; while [[ "$creds" == " "* ]]; do creds="${creds# }"; done; break ;;
    esac
done < "$pwd_file"
[[ -n "$creds" ]] || { echo "Error: no credentials for host '$host' in $pwd_file" >&2; exit 1; }
user="${creds%%/*}"
pass="${creds#*/}"

run_one() {
    local id="$1"
    case "$state" in
        on|off)
            local value
            value=$([[ "$state" == "on" ]] && echo true || echo false)
            local response
            response=$(curl -sf -m 10 --digest -u "${user}:${pass}" \
                "http://${host}/rpc/Switch.Set?id=${id}&on=${value}")
            local was_on
            was_on=$(echo "$response" | jq -r '.was_on')
            echo "Socket ${id} on ${host}: turned ${state} (was_on: ${was_on})"
            ;;
        status|get)
            local response
            response=$(curl -sf -m 10 --digest -u "${user}:${pass}" \
                "http://${host}/rpc/Switch.GetStatus?id=${id}")
            echo "$response" | jq -r \
                '"Socket \(.id) on '"${host}"': output=\(.output) power=\(.apower)W voltage=\(.voltage)V current=\(.current)A energy=\(.aenergy.total)Wh"'
            ;;
    esac
}

run_led() {
    case "$state" in
        on|off)
            local mode
            mode=$([[ "$state" == "on" ]] && echo power || echo off)
            curl -sf -m 10 --digest -u "${user}:${pass}" -G \
                --data-urlencode "config={\"leds\":{\"mode\":\"${mode}\"}}" \
                "http://${host}/rpc/POWERSTRIP_UI.SetConfig" >/dev/null
            echo "LEDs on ${host}: mode set to ${mode}"
            ;;
        status|get)
            local response
            response=$(curl -sf -m 10 --digest -u "${user}:${pass}" \
                "http://${host}/rpc/POWERSTRIP_UI.GetConfig")
            echo "$response" | jq -r '"LEDs on '"${host}"': mode=\(.leds.mode)"'
            ;;
        brightness)
            if [[ "$value" == "status" || "$value" == "get" ]]; then
                local response
                response=$(curl -sf -m 10 --digest -u "${user}:${pass}" \
                    "http://${host}/rpc/POWERSTRIP_UI.GetConfig")
                echo "$response" | jq -r '"LED brightness on '"${host}"': \(.leds.colors.power.brightness)"'
            else
                curl -sf -m 10 --digest -u "${user}:${pass}" -G \
                    --data-urlencode "config={\"leds\":{\"colors\":{\"power\":{\"brightness\":${value}}}}}" \
                    "http://${host}/rpc/POWERSTRIP_UI.SetConfig" >/dev/null
                echo "LED brightness on ${host}: set to ${value}"
            fi
            ;;
    esac
}

if [[ "$socket" == "led" ]]; then
    run_led
elif [[ "$socket" == "all" ]]; then
    for id in 0 1 2 3; do
        run_one "$id"
    done
else
    run_one "$socket"
fi
