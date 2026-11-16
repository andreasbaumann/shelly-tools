# check_shelly

A Nagios/Icinga plugin for Shelly Gen2+ RPC devices, developed against
Shelly Power Strip Gen4 devices (model `S4PL-00416EU`). Each invocation
checks one device (`--host=...`); monitoring several strips just means
one set of service definitions per host, as shown below for
`europower1.lan`/`europower2.lan`.

## What it does

`check_shelly` is a Bash script that queries a Shelly device's local RPC
API (`/rpc/Switch.GetStatus`, `/rpc/Shelly.GetStatus`) over HTTP Digest
auth and exits with a standard Nagios state (`OK`/`WARNING`/`CRITICAL`/
`UNKNOWN`) plus perfdata, depending on `--mode`:

- **`power`** — per-socket power draw (W) and current (A); warn/crit on
  a configurable wattage threshold.
- **`voltage`** — per-socket mains voltage; warn/crit outside a
  configurable safe band (default tuned for 230V EU mains).
- **`wifi`** — Wi-Fi signal strength (RSSI); also CRITICAL if the device
  isn't actually connected.
- **`health`** — pending restart, pending firmware update, and staleness
  of the last NTP time sync.
- **`state`** — asserts specific sockets are on and/or off, e.g. "the
  NAS socket must never be off." Severity is configurable per socket
  (`--expect-on`/`--expect-off` → CRITICAL, `--expect-on-warn`/
  `--expect-off-warn` → WARNING), since whether an on/off mismatch is
  critical or just worth a warning depends on what's plugged in, not on
  which direction the mismatch goes.

`--expect-on`/`--expect-off`/`--expect-on-warn`/`--expect-off-warn` also
fold into `power` and `voltage`, so a single check can assert a
threshold and a state together.

Run `./check_shelly --help` for the full option list.

## Requirements

- `curl` (with Digest auth support)
- `jq`

Both are standard packages on essentially any Linux distribution.

## Installation

```sh
cp check_shelly /usr/lib/nagios/plugins/check_shelly
chmod 755       /usr/lib/nagios/plugins/check_shelly
```

Credentials are read via `--pwdfile=FILE` or explicit `--user=`/`--password=`.
This project's own tooling keeps that file at `~/.config/shelly/credentials`,
one line per device, keyed by hostname (each device has its own admin
password — see [credentials](../../tools/README.md#authentication) in
`tools/README.md`):

```
europower1.lan:admin/secret1
europower2.lan:admin/secret2
```

The same `--pwdfile` works for every host — `check_shelly` looks up the
line matching whatever `--host` it's given.

## Usage

```sh
./check_shelly --host=europower1.lan --pwdfile=~/.config/shelly/credentials --mode=power --warn=1800 --crit=2300
./check_shelly --host=europower1.lan --pwdfile=~/.config/shelly/credentials --mode=voltage
./check_shelly --host=europower1.lan --pwdfile=~/.config/shelly/credentials --mode=wifi
./check_shelly --host=europower1.lan --pwdfile=~/.config/shelly/credentials --mode=health
./check_shelly --host=europower1.lan --pwdfile=~/.config/shelly/credentials --mode=state --expect-on=3 --expect-off-warn=2

./check_shelly --host=europower2.lan --pwdfile=~/.config/shelly/credentials --mode=power --warn=1800 --crit=2300
```

## Example configurations

### Classic Nagios

One generic command, with mode and any extra flags passed through as
plain arguments — `commands.cfg`:

```
define command {
    command_name    check_shelly
    command_line    $USER1$/check_shelly --host=$ARG1$ --pwdfile=$ARG2$ --mode=$ARG3$ $ARG4$
}
```

`services.cfg`, one service per mode:

```
define service {
    host_name           europower1
    service_description Shelly Power
    check_command       check_shelly!europower1.lan!/home/build/.config/shelly/credentials!power!--warn=1800 --crit=2300
    use                 generic-service
}

define service {
    host_name           europower1
    service_description Shelly Voltage
    check_command       check_shelly!europower1.lan!/home/build/.config/shelly/credentials!voltage!
    use                 generic-service
}

define service {
    host_name           europower1
    service_description Shelly Wifi
    check_command       check_shelly!europower1.lan!/home/build/.config/shelly/credentials!wifi!
    use                 generic-service
}

define service {
    host_name           europower1
    service_description Shelly Health
    check_command       check_shelly!europower1.lan!/home/build/.config/shelly/credentials!health!
    use                 generic-service
}

define service {
    host_name           europower1
    service_description Shelly NAS Socket State
    check_command       check_shelly!europower1.lan!/home/build/.config/shelly/credentials!state!--expect-on=3 --expect-off-warn=2
    use                 generic-service
}
```

Repeat the same set of service definitions with `host_name europower2`
and `europower2.lan` to cover the second strip — the shared `pwdfile`
already holds credentials for both:

```
define service {
    host_name           europower2
    service_description Shelly Power
    check_command       check_shelly!europower2.lan!/home/build/.config/shelly/credentials!power!--warn=1800 --crit=2300
    use                 generic-service
}
```

(The trailing `!` on the services with no extra flags is required — it's
the empty `$ARG4$`.)

### Icinga2

A single `CheckCommand` covering every mode (optional arguments only
rendered `set_if` their var is actually set), applied per-host:

```
object CheckCommand "shelly" {
    command = [ PluginDir + "/check_shelly" ]
    arguments = {
        "--host" = "$shelly_host$"
        "--pwdfile" = "$shelly_pwdfile$"
        "--mode" = "$shelly_mode$"
        "--warn" = { value = "$shelly_warn$"; set_if = "$shelly_warn$" }
        "--crit" = { value = "$shelly_crit$"; set_if = "$shelly_crit$" }
        "--expect-on" = { value = "$shelly_expect_on$"; set_if = "$shelly_expect_on$" }
        "--expect-off" = { value = "$shelly_expect_off$"; set_if = "$shelly_expect_off$" }
        "--expect-on-warn" = { value = "$shelly_expect_on_warn$"; set_if = "$shelly_expect_on_warn$" }
        "--expect-off-warn" = { value = "$shelly_expect_off_warn$"; set_if = "$shelly_expect_off_warn$" }
    }
}

object Host "europower1" {
    address = "192.168.1.x"
    vars.shelly_host = "europower1.lan"
    vars.shelly_pwdfile = "/home/build/.config/shelly/credentials"
}

object Host "europower2" {
    vars.shelly_host = "europower2.lan"
    vars.shelly_pwdfile = "/home/build/.config/shelly/credentials"
}

apply Service "shelly-power" {
    check_command = "shelly"
    vars.shelly_mode = "power"
    vars.shelly_warn = "1800"
    vars.shelly_crit = "2300"
    assign where host.vars.shelly_host
}

apply Service "shelly-voltage" {
    check_command = "shelly"
    vars.shelly_mode = "voltage"
    assign where host.vars.shelly_host
}

apply Service "shelly-wifi" {
    check_command = "shelly"
    vars.shelly_mode = "wifi"
    assign where host.vars.shelly_host
}

apply Service "shelly-health" {
    check_command = "shelly"
    vars.shelly_mode = "health"
    assign where host.vars.shelly_host
}

apply Service "shelly-nas-state" {
    check_command = "shelly"
    vars.shelly_mode = "state"
    vars.shelly_expect_on = "3"
    vars.shelly_expect_off_warn = "2"
    assign where host.vars.shelly_host
}
```

Each `apply Service` already matches every `Host` with `vars.shelly_host`
set, so adding `europower2` above is enough — no need to duplicate the
`apply Service` blocks per device.

## Developer reference

RPC endpoints used, and the devices' HTTP Digest (SHA-256) auth
requirement, are documented in [`../../tools/README.md`](../../tools/README.md#rpc-api).
Gen2+/3/4 RPC reference: https://shelly-api-docs.shelly.cloud/gen2/

## Munin companion

See [`../munin/shelly_`](../munin/shelly_) in this repository for a
Munin plugin graphing the same per-socket power/voltage/energy metrics,
plus Wi-Fi signal, over time.

## Generated with

This code was generated with [Claude Code](https://claude.ai/code) (Sonnet 5).
