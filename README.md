# Reese Nelson

Currently building internal automation tools at work, including an email templater, a Windows media creation utility, and a chatbot for field technicians. Everything below is separate, self-directed infrastructure work on my own time.

Remote · Certified Kubernetes Administrator · [LinkedIn](https://www.linkedin.com/in/reesenelson/)

Normally this kind of infrastructure work would come from a job, but I wanted to learn the open-source side of it properly, so I've been building my own. My homelab runs on GitOps because I got tired of forgetting what I changed, and most of what's below followed from that. I'm still filling gaps and these repos are where I'm filling them.

## The Homelab

```mermaid
flowchart LR
  R["ubernutty-cluster<br/>(git repo)"] --> F["Flux<br/>reconciles every 10 min"]
  S["SOPS + age"] -. decrypts secrets .-> F
  F --> I[infrastructure]
  F --> M[monitoring]
  F --> A[apps]
  I --> RN["Renovate<br/>CronJob"]
  M --> P["Prometheus<br/>+ Grafana"]
  A --> L[Linkding]
  A --> AB[Audiobookshelf]
  L --> CF["Cloudflare Tunnel<br/>(outbound, no open ports)"]
  AB --> CF
```

<!-- LIVE:START -->
### Live cluster state

| | |
|---|---|
| Flux | `v2.9.5` |
| Last infrastructure change | 2026-09-07 |
| Renovate dependency PRs | none open, 6 merged in the last 30 days |
| Apps under GitOps | 2 |

<sub>Updated 2026-09-08 11:11 UTC</sub>
<!-- LIVE:END -->

## Projects

| What | Where | What's in there |
|---|---|---|
| GitOps and continuous reconciliation | [ubernutty-cluster](https://github.com/MechHead777/ubernutty-cluster) | Flux applying layered kustomizations, cluster state driven entirely from git |
| Secrets management | [ubernutty-cluster](https://github.com/MechHead777/ubernutty-cluster) | SOPS + age. No plaintext secret has ever been committed |
| Observability | [ubernutty-cluster](https://github.com/MechHead777/ubernutty-cluster) | kube-prometheus-stack dashboards |
| Dependency hygiene | [ubernutty-cluster](https://github.com/MechHead777/ubernutty-cluster) | Self-hosted Renovate CronJob raising PRs when a new version releases |
| CI/CD and releases | [devops-study-app](https://github.com/MechHead777/devops-study-app) | GitHub Actions building and pushing images to GHCR, release-please handling versioning |
| Container fundamentals | [container-practice](https://github.com/MechHead777/container-practice) | Multi-stage builds |
| Environment management | [dotfiles](https://github.com/MechHead777/dotfiles) | chezmoi-managed shell, Neovim, and mise-pinned runtimes across machines |
| Declarative systems | [nixos-backup](https://github.com/MechHead777/nixos-backup) | Whole desktop reproducible from a flake with one command |
| Firmware debugging | [my-vial-keyboards](https://github.com/MechHead777/my-vial-keyboards) | QMK/Vial keymaps, plus porting boards off memory-starved AVR chips to RP2040 |

## Certifications

**Certified Kubernetes Administrator (CKA)** · Credential ID `LF-rf1c3fcxxm` · [verify](https://training.linuxfoundation.org/certification/verify/)

CompTIA A+, Network+, and Security+: earned, now lapsed. Listing them for accuracy, not claiming them as current.
