# Shelly Power Strip Gen4

Control and monitoring for Shelly Power Strip Gen4 devices, talked to
directly over their local RPC API (the devices are local-only — no
cloud/MQTT). All tooling is host-parameterized, so it works against any
number of these strips; two are deployed on this network today.

## Devices

- Product: [Shelly Power Strip Gen4](https://kb.shelly.cloud/knowledge-base/shelly-power-strip-gen4)
- Model `S4PL-00416EU`, gen `4`, app `PowerStrip`
- 4 switchable sockets per device, ids `0`-`3`
- Connected via Wi-Fi; cloud/MQTT/WS integrations disabled, control is local-only

| Hostname | IP | Device id / realm | Firmware |
|---|---|---|---|
| `europower1.lan` | `192.168.1.x` | `shellypstripg4-xxxxxxxxxxxx` | `1.7.99-powerstripg4prod1` |
| `europower2.lan` | — | — | — |

Each device has its own admin password — see [credentials](tools/README.md#authentication)
in `tools/README.md` for the per-host credentials file format.

## Layout

- **[`tools/`](tools/README.md)** — `shelly_switch.sh`, an interactive
  on/off/status CLI. Also documents the RPC API and authentication —
  shared background for everything below.
- **[`plugins/nagios/`](plugins/nagios/README.md)** — `check_shelly`,
  a Nagios/Icinga plugin (power/voltage/wifi/health/state checks).
- **[`plugins/munin/`](plugins/munin/README.md)** — `shelly_`, a Munin
  plugin graphing power/voltage/energy/wifi over time.
- **[`test/`](test/run_all.sh)** — integration tests for all three,
  run against the real devices via `test/run_all.sh`.

## License

GPLv3 — see [LICENSE](LICENSE) and [AUTHORS](AUTHORS).

## Generated with

This code was generated with [Claude Code](https://claude.ai/code) (Sonnet 5).
