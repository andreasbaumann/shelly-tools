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

Example (raw curl, digest auth):

```sh
curl --digest -u admin:PASSWORD \
  "http://europower1.lan/rpc/Switch.GetStatus?id=3"
```

## `shelly_switch.sh`

Interactive on/off/status CLI for day-to-day use.

```sh
./shelly_switch.sh <host> <socket 0-3|all> <on|off|status>
```

Examples:

```sh
./shelly_switch.sh europower1.lan 3 on
./shelly_switch.sh europower1.lan 3 off
./shelly_switch.sh europower1.lan 3 status
./shelly_switch.sh europower1.lan all status
./shelly_switch.sh europower1.lan all off
```

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
