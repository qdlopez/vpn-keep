# VPN Keeper

**Multi-source subscription aggregator, node validator, and Xray proxy auto-maintenance for AI agents.**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Overview

VPN Keeper is an open-source infrastructure tool that automatically fetches, validates, and selects proxy nodes from multiple public subscription sources. Designed as an **AI agent skill**, it enables autonomous agents to maintain network connectivity by continuously verifying and rotating proxy configurations.

The project solves a real pain point for developers and AI agents in restricted network environments: free proxy nodes are unreliable by nature — this tool automates the entire lifecycle from discovery to deployment.

## Features

- **Multi-source aggregation** — Fetches from 6+ verified public subscription sources (GitHub repos, clashnode, v2rayshare, etc.)
- **Intensive node validation** — 30-thread TCP handshake probing + protocol-layer priority scoring (vless+vision+reality > trojan > vmess > ss)
- **Real-world verification** — Only nodes that return HTTP 200 from Google are accepted; TCP handshake success alone is not enough
- **Zero-touch auto-repair** — Cron-based 10-minute health check with automatic failover to backup configurations
- **Configuration-driven** — Add new sources or tweak thresholds via JSON — no script modification needed
- **Agent-ready** — Structured as a Hermes Agent skill with full SKILL.md documentation, making it directly usable by AI agents

## Architecture

```
Config Load → Multi-source Fetch → Decode & Deduplicate → 30-thread TCP Test
     → Google HTTP 200 Verification → Xray Config Generation → System Proxy Setup
```

## Quick Start

```bash
# Run the complete workflow
bash scripts/vpn_keeper.sh

# Validate nodes from a subscription file
python3 scripts/validate_nodes.py subs/latest.txt
```

## Configuration

| File | Purpose |
|------|---------|
| `config/sources.json` | Subscription source definitions (add/remove sources here) |
| `config/settings.json` | Global parameters (Xray paths, ports, latency thresholds) |

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
