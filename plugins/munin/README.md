# shelly_

Munin plugin for Shelly Gen2+ RPC devices, developed against a Shelly
Power Strip Gen4 (model `S4PL-00416EU`).

## What it monitors

Four graphs, installed from a single plugin file via symlinks:

### shelly_power — per-socket power draw

| Data series | Draw | Description |
|---|---|---|
| Socket 0-3 (W) | stacked area | Real power drawn by each socket |

### shelly_voltage — per-socket mains voltage

| Data series | Draw | Description |
|---|---|---|
| Socket 0-3 (V) | line | Mains voltage measured at each socket |

### shelly_energy — per-socket cumulative energy

| Data series | Draw | Description |
|---|---|---|
| Socket 0-3 (Wh) | line | Energy drawn since last device boot/reset — resets to 0 on reboot, producing a sawtooth |

### shelly_wifi — Wi-Fi signal strength

| Data series | Draw | Description |
|---|---|---|
| RSSI (dBm) | line, warn -70 / crit -80 | Signal strength as seen by the device itself |

Shelly RPC endpoints used: `GET /rpc/Switch.GetStatus?id=<0-3>`,
`GET /rpc/Shelly.GetStatus`.

## Requirements

- `curl` (with Digest auth support)
- Perl 5 with `JSON::PP` (core module — no extra install needed)

Authentication is HTTP Digest (SHA-256), shelled out to `curl` rather
than done in-process: LWP's built-in Digest support historically targets
MD5, and Shelly Gen2+/3/4 devices require SHA-256.

## Installation

```sh
cp shelly_ /usr/share/munin/plugins/
chmod 755  /usr/share/munin/plugins/shelly_
ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_power
ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_voltage
ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_energy
ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_wifi
```

## Configuration

Create `/etc/munin/plugin-conf.d/shelly`:

```ini
[shelly_*]
env.host europower1.lan
env.pwdfile /home/build/.config/shelly/credentials
# sockets to graph for power/voltage/energy (default: 0,1,2,3)
env.sockets 0,1,2,3
# curl timeout in seconds (default: 10)
env.timeout 10
```

Or, instead of `env.pwdfile`, explicit credentials:

```ini
[shelly_*]
env.host europower1.lan
env.user admin
env.password yourpassword
```

Graphing only a subset of sockets (e.g. just the one the NAS is plugged
into) — `shelly_power`/`shelly_voltage`/`shelly_energy` only draw the
listed sockets, `shelly_wifi` is unaffected since it's device-wide:

```ini
[shelly_*]
env.host europower1.lan
env.pwdfile /home/build/.config/shelly/credentials
env.sockets 3
```

Then restart the Munin node:

```sh
systemctl restart munin-node
```

## Verifying the plugin

```sh
# Test autoconf (should print "yes")
munin-run shelly_power autoconf

# Test config output
munin-run shelly_power config
munin-run shelly_voltage config
munin-run shelly_energy config
munin-run shelly_wifi config

# Test data fetch
munin-run shelly_power
munin-run shelly_voltage
munin-run shelly_energy
munin-run shelly_wifi
```

`munin-node-configure --suggest` will also list the plugin as available
once credentials are in place.

## Developer reference

The graph shown depends on the symlink name the script is invoked as
(`shelly_power`, `shelly_voltage`, `shelly_energy`, or `shelly_wifi`),
read from `$0`. RPC endpoint details and the device's auth requirement
are documented in [`../../tools/README.md`](../../tools/README.md#rpc-api).
Gen2+/3/4 RPC reference: https://shelly-api-docs.shelly.cloud/gen2/

## Nagios/Icinga companion

See [`../nagios/check_shelly`](../nagios/check_shelly) in this
repository for a Nagios/Icinga plugin covering the same metrics with
WARNING/CRITICAL thresholds.

## Generated with

This code was generated with [Claude Code](https://claude.ai/code) (Sonnet 5).
