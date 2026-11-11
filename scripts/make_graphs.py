import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = "results/graphs/"

# E2: detection latency per attack, Method A vs B (mean +- sd; missed runs shown as text)
attacks = ["scan", "synflood", "icmp", "ssh"]
labels = ["Port scan", "SYN flood", "ICMP flood", "SSH brute force"]
fig, ax = plt.subplots(figsize=(8, 5))
w = 0.38
for k, (col, name) in enumerate([("suricata_latency_s", "Method B: Suricata"),
                                 ("prometheus_latency_s", "Method A: Prometheus")]):
    means, sds, notes = [], [], []
    for a in attacks:
        d = pd.read_csv(f"results/e2_{a}.csv")
        v = pd.to_numeric(d[col], errors="coerce")
        means.append(v.mean() if v.notna().any() else 0)
        sds.append(v.std() if v.notna().sum() > 1 else 0)
        notes.append(f"{v.notna().sum()}/{len(v)}")
    xs = [i + (k - 0.5) * w for i in range(len(attacks))]
    ax.bar(xs, means, w, yerr=sds, capsize=4, label=name)
    for x, m, n in zip(xs, means, notes):
        ax.text(x, m + 0.3, n if m > 0 else "missed\n" + n, ha="center", fontsize=8)
ax.set_xticks(range(len(attacks)))
ax.set_xticklabels(labels)
ax.set_ylabel("Detection latency (s)")
ax.set_title("E2: detection latency (labels = runs detected)")
ax.legend()
fig.tight_layout()
fig.savefig(OUT + "e2_latency.png", dpi=150)

# E4: fault detection time per run
d = pd.read_csv("results/e4_fault.csv")
fig, ax = plt.subplots(figsize=(7, 4))
ax.bar(d["run"], d["alert_latency_s"])
ax.axhline(15, color="red", linestyle="--", label="Target 15 s")
ax.set_xlabel("Run")
ax.set_ylabel("Fault to alert (s)")
ax.set_title("E4: service-down detection time")
ax.legend()
fig.tight_layout()
fig.savefig(OUT + "e4_fault.png", dpi=150)

# E1: monitoring OFF vs ON (fixed 1 Gbps load)
d = pd.read_csv("results/e1_overhead.csv")
g = d.groupby("mode")[["tcp_mbps", "udp_jitter_ms", "ping_avg_ms"]].agg(["mean", "std"])
fig, axs = plt.subplots(1, 3, figsize=(11, 4))
for ax, c, t in zip(axs, ["tcp_mbps", "udp_jitter_ms", "ping_avg_ms"],
                    ["TCP throughput (Mbps)", "UDP jitter (ms)", "Ping latency (ms)"]):
    ax.bar(["off", "on"], [g[c]["mean"]["off"], g[c]["mean"]["on"]],
           yerr=[g[c]["std"]["off"], g[c]["std"]["on"]], capsize=4)
    ax.set_title(t)
fig.suptitle("E1: monitoring OFF vs ON")
fig.tight_layout()
fig.savefig(OUT + "e1_overhead.png", dpi=150)

# E5: CPU vs offered load
d = pd.read_csv("results/e5_scaling.csv")
p = d.groupby(["load_mbps", "container"])["cpu_pct"].mean().unstack()
fig, ax = plt.subplots(figsize=(8, 5))
for c in ["suricata", "grafana", "prometheus", "loki", "promtail", "node_exporter"]:
    ax.plot(p.index, p[c], marker="o", label=c)
ax.set_xlabel("Offered load (Mbps)")
ax.set_ylabel("CPU (% of one core)")
ax.set_title("E5: per-container CPU vs load")
ax.legend()
fig.tight_layout()
fig.savefig(OUT + "e5_cpu.png", dpi=150)
print("graphs saved in results/graphs/")
