# tools

Interactive CLI tooling for the Shelly Power Strip Gen4 (see the
top-level [README](../README.md) for what the device is), plus the RPC
API and authentication background shared by the Nagios/Munin plugins in
`../plugins/`.

## Authentication

The device requires **HTTP Digest authentication** (`WWW-Authenticate: Digest`,
`algorithm=SHA-256`) on all `/rpc/*` endpoints once a password is set. An
unauthenticated request returns `401 Unauthorized` with the realm string
shown above.

Credentials live at `~/.config/shelly/credentials` (mode `600`), one line
in the format:

```
username/password
```

The username is always `admin` for this device.

LWP's built-in Digest auth support historically targets MD5, and this
device requires SHA-256, so the Munin plugin shells out to `curl --digest`
rather than doing auth in-process — same reasoning as this script.

## RPC API

Base docs for the Shelly Gen2+ RPC framework (applies to Gen3/Gen4 devices
as well, same component model): https://shelly-api-docs.shelly.cloud/gen2/

Endpoints used across this repo:

| Endpoint | Purpose |
|---|---|
| `GET /rpc/Shelly.GetStatus` | Full device status (all components) |
| `GET /rpc/Shelly.GetDeviceInfo` | Model/firmware identity |
| `GET /rpc/Switch.GetStatus?id=<0-3>` | Status of a single socket |
| `GET /rpc/Switch.Set?id=<0-3>&on=<true\|false>` | Turn a socket on/off |
| `GET /rpc/POWERSTRIP_UI.GetConfig` | Current LED indication config (all 4 sockets) |
| `GET /rpc/POWERSTRIP_UI.SetConfig?config=<json>` | Change LED indication config |

`Switch.GetStatus` fields of interest: `output` (bool), `apower` (W),
`voltage` (V), `current` (A), `pf` (power factor), `aenergy.total` (Wh,
cumulative since last boot/reset — resets to 0 on reboot, so treat it as a
gauge, not an ever-increasing counter).

`Shelly.GetStatus` fields of interest beyond the per-switch ones above:
`sys.restart_required`, `sys.available_updates` (empty object = no pending
firmware update), `sys.unixtime` / `sys.last_sync_ts` (time since last NTP
sync), `wifi.rssi` (dBm) / `wifi.status` (`"got ip"` when actually
connected), `cloud.connected` / `mqtt.connected` / `ws.connected` (all
`false` here — this device is local-only by design).

`POWERSTRIP_UI` controls the LED indication for all 4 sockets as one unit
(there's no per-socket on/off for the LEDs themselves, though per-socket
colors can be set under `leds.colors["switch:0"]` etc. — see the [Gen2+ RPC
docs](https://shelly-api-docs.shelly.cloud/gen2/)). `leds.mode` is the main
switch: `"power"` (brightness reflects power draw — the default), `"switch"`
(reflects on/off state), or `"off"` (LEDs fully disabled, including the
green power/connected light). There's also `night_mode` (`enable`,
`brightness`, `active_between: ["HH:MM","HH:MM"]`) to just dim the LEDs on a
schedule instead of disabling them outright.

Example (raw curl, digest auth, disabling the LEDs):

```sh
curl --digest -u admin:PASSWORD -G \
  --data-urlencode 'config={"leds":{"mode":"off"}}' \
  "http://europower1.lan/rpc/POWERSTRIP_UI.SetConfig"
```

Note: `POWERSTRIP_UI.SetConfig` must be called as a `GET` with
`curl -G --data-urlencode` (as above), not a `POST` with a JSON body — the
device returns `400 Bad Request` to a body-less POST before curl's digest
auth gets a chance to retry with credentials, so the handshake never
completes.

Example (raw curl, digest auth):

```sh
curl --digest -u admin:PASSWORD \
  "http://europower1.lan/rpc/Switch.GetStatus?id=3"
```

## `shelly_switch.sh`

Interactive on/off/status CLI for day-to-day use.

```sh
./shelly_switch.sh <host> <socket 0-3|all|led> <on|off|status>
```

Examples:

```sh
./shelly_switch.sh europower1.lan 3 on
./shelly_switch.sh europower1.lan 3 off
./shelly_switch.sh europower1.lan 3 status
./shelly_switch.sh europower1.lan all status
./shelly_switch.sh europower1.lan all off
./shelly_switch.sh europower1.lan led off      # disable all LED indication
./shelly_switch.sh europower1.lan led on       # back to "power" mode
./shelly_switch.sh europower1.lan led status
```

`led on`/`led off` map to the `POWERSTRIP_UI` modes `power`/`off` (see
above) and apply to all 4 sockets' LEDs at once — there's no per-socket
LED on/off, only per-socket LED *color* (not exposed by this script).

Requires `curl` and `jq`. Reads credentials from
`~/.config/shelly/credentials` (override with `SHELLY_PWD_FILE=/path/to/file`).

## Findings / gotchas

- `europower1` alone does not resolve on this network; use the full name
  `europower1.lan` (or the IP `192.168.1.3` directly).
- `curl`'s `-f` flag combined with `--digest` fails silently (exit 22, no
  body) if credentials are wrong or the digest handshake fails — drop `-f`
  temporarily when debugging.
- All four sockets were observed to be "on" (`output: true`) by default
  with nothing drawing power, except socket 3 which had a small steady
  load (~5W) — worth knowing before setting tight power thresholds in the
  Nagios plugin.

## Generated with

This code was generated with [Claude Code](https://claude.ai/code) (Sonnet 5).
