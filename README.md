# Shelly Power Strip Gen4

Control and monitoring for a Shelly Power Strip Gen4, talked to directly
over its local RPC API (the device is local-only — no cloud/MQTT).

## Device

- Product: [Shelly Power Strip Gen4](https://kb.shelly.cloud/knowledge-base/shelly-power-strip-gen4)
- Hostname on this network: `europower1.lan` (IP `192.168.1.3`)
- Device id / realm: `shellypstripg4-d885acecee84`
- Model `S4PL-00416EU`, gen `4`, app `PowerStrip`, fw `1.7.99-powerstripg4prod1`
- 4 switchable sockets, ids `0`-`3`
- Connected via Wi-Fi (SSID `Fornost`); cloud/MQTT/WS integrations disabled, control is local-only

## Layout

- **[`tools/`](tools/README.md)** — `shelly_switch.sh`, an interactive
  on/off/status CLI. Also documents the RPC API and authentication —
  shared background for everything below.
- **[`plugins/nagios/`](plugins/nagios/README.md)** — `check_shelly`,
  a Nagios/Icinga plugin (power/voltage/wifi/health/state checks).
- **[`plugins/munin/`](plugins/munin/README.md)** — `shelly_`, a Munin
  plugin graphing power/voltage/energy/wifi over time.
- **[`test/`](test/run_all.sh)** — integration tests for all three,
  run against the real device via `test/run_all.sh`.

## License

GPLv3 — see [LICENSE](LICENSE) and [AUTHORS](AUTHORS).

## Generated with

This code was generated with [Claude Code](https://claude.ai/code) (Sonnet 5).
