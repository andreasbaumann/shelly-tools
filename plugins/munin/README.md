# shelly_

Munin plugin for Shelly Gen2+ RPC devices, developed against Shelly
Power Strip Gen4 devices (model `S4PL-00416EU`). One plugin instance
monitors one device; run multiple instances (via Munin's standard
multi-instance symlink naming) to monitor several strips, e.g.
`europower1.lan` and `europower2.lan`.

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

### shelly_energy — per-socket energy consumption

| Data series | Draw | Description |
|---|---|---|
| Socket 0-3 (Wh per hour) | stacked area, plus a `Total` line | Energy consumed by each socket, derived by RRD from the device's cumulative counter |

The device exposes energy as `aenergy.total`, a counter that only ever
grows (and resets to 0 on reboot). Graphing that directly gives an
ever-rising ramp with a sawtooth, which says nothing about actual usage,
so the plugin reports the counter as-is and declares the fields as
`type DERIVE` with `min 0`: RRD differentiates the counter and
`graph_period hour` renders the result as Wh per hour.

Two consequences worth knowing:

- `min 0` makes the negative delta of a reboot reset fall out of range,
  so RRD stores it as *unknown* — a small gap in the graph instead of a
  spike. (`COUNTER` would misread the same drop as a 64-bit wraparound
  and invent an enormous value; `DERIVE` is the correct type here.)
- Wh per hour is dimensionally identical to the watts in
  `shelly_power`, so the two graphs track each other. The data differs
  in quality, though: `apower` is a single instantaneous sample per
  poll, while the derived counter is the device's own integration over
  the entire interval, so a kettle that runs for 40 seconds shows up
  here and is usually invisible in the power graph.

What this graph still cannot do is answer "how many kWh did I use
yesterday" — it is a rate, and RRD rescales it to each graph's own
consolidation (5 min on the day graph, 2 h on the month graph, 1 day on
the year graph). Munin's legend reports Cur/Min/Avg/Max but no integral
(rrdtool's `VDEF ... TOTAL` would, but Munin does not expose VDEFs), so
a true per-day/per-month kWh figure means reading Avg off the legend and
multiplying by the window by hand.

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
```

For a single device, symlink the four graph types directly:

```sh
ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_power
ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_voltage
ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_energy
ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_wifi
```

For multiple devices, append an instance suffix per Munin's standard
multi-instance convention (one set of four symlinks per device):

```sh
for g in power voltage energy wifi; do
    ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_${g}_europower1
    ln -s /usr/share/munin/plugins/shelly_ /etc/munin/plugins/shelly_${g}_europower2
done
```

## Configuration

Create `/etc/munin/plugin-conf.d/shelly`, one stanza per device instance
(a bare `[shelly_*]` stanza instead applies the same `env.host` to every
instance, which only makes sense for a single device):

```ini
[shelly_*_europower1]
env.host europower1.lan
env.pwdfile /home/build/.config/shelly/credentials
# sockets to graph for power/voltage/energy (default: 0,1,2,3)
env.sockets 0,1,2,3
# curl timeout in seconds (default: 10)
env.timeout 10

[shelly_*_europower2]
env.host europower2.lan
env.pwdfile /home/build/.config/shelly/credentials
env.sockets 0,1,2,3
env.timeout 10
```

`env.pwdfile` holds credentials for both devices, keyed by hostname — see
[credentials](../../tools/README.md#authentication) in `tools/README.md`.
Or, instead of `env.pwdfile`, explicit credentials per instance:

```ini
[shelly_*_europower1]
env.host europower1.lan
env.user admin
env.password secret1

[shelly_*_europower2]
env.host europower2.lan
env.user admin
env.password secret2
```

Graphing only a subset of sockets (e.g. just the one the NAS is plugged
into) — `shelly_power`/`shelly_voltage`/`shelly_energy` only draw the
listed sockets, `shelly_wifi` is unaffected since it's device-wide:

```ini
[shelly_*_europower1]
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
munin-run shelly_power_europower1 autoconf

# Test config output
munin-run shelly_power_europower1 config
munin-run shelly_voltage_europower1 config
munin-run shelly_energy_europower1 config
munin-run shelly_wifi_europower1 config

# Test data fetch
munin-run shelly_power_europower1
munin-run shelly_voltage_europower1
munin-run shelly_energy_europower1
munin-run shelly_wifi_europower1
```

(drop the `_europower1` suffix for a single-device install, or repeat
against `_europower2` for the second device.)

`munin-node-configure --suggest` will also list the plugin as available
once credentials are in place.

### Migrating an existing install

RRD fixes a data source's type when the file is created, and Munin will
not change it afterwards. An install that already graphed the old
cumulative `shelly_energy` therefore keeps writing `GAUGE` files, and the
new `DERIVE` declaration has no effect until the RRDs are converted:

```sh
# per socket, per device; the DS name in Munin's RRDs is always "42"
rrdtool tune /var/lib/munin/<group>/<host>-shelly_energy-socket0-g.rrd -d 42:DERIVE
```

Or simply move the old `shelly_energy-*` `.rrd` files aside and let Munin
recreate them on the next run. Either way the stored history is lost — it
was a counter ramp, not consumption, so there is little to preserve.

The `shelly_power`, `shelly_voltage` and `shelly_wifi` graphs are
unaffected and need no migration.

## Developer reference

The graph shown depends on the symlink name the script is invoked as
(`shelly_power`, `shelly_voltage`, `shelly_energy`, or `shelly_wifi`,
each optionally followed by `_<instance>` per Munin's multi-instance
convention — e.g. `shelly_power_europower2`), read from `$0`. RPC
endpoint details and the devices' auth requirement are documented in
[`../../tools/README.md`](../../tools/README.md#rpc-api). Gen2+/3/4 RPC
reference: https://shelly-api-docs.shelly.cloud/gen2/

## Nagios/Icinga companion

See [`../nagios/check_shelly`](../nagios/check_shelly) in this
repository for a Nagios/Icinga plugin covering the same metrics with
WARNING/CRITICAL thresholds.

## Generated with

This code was generated with [Claude Code](https://claude.ai/code) (Sonnet 5).
