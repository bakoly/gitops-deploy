#!/usr/bin/env bash
# bagitops use-router / cancel-use-router

BAGITOPS_USE_ROUTER_ORIG="/etc/bagitops-use-router.orig-route"
BAGITOPS_USE_ROUTER_SERVICE="/etc/systemd/system/bagitops-use-router.service"

cmd_use_router() {
  local router_ip="${1:-}"
  [[ -n "$router_ip" ]] || die "usage: bagitops use-router <router-ip>"
  [[ $EUID -eq 0 ]] || die "use-router requires root — run with sudo"
  [[ "$router_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid IP address: $router_ip"

  # Save the original default gateway once (first run only)
  if [[ ! -f "$BAGITOPS_USE_ROUTER_ORIG" ]]; then
    local orig_gw
    orig_gw=$(ip -4 route | awk '/^default/{print $3; exit}')
    echo "${orig_gw:-none}" > "$BAGITOPS_USE_ROUTER_ORIG"
  fi

  # Switch default route
  ip route replace default via "$router_ip"

  # Write/overwrite systemd service with new IP
  cat > "$BAGITOPS_USE_ROUTER_SERVICE" <<EOF
[Unit]
Description=bagitops use-router (default route via ${router_ip})
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/ip route replace default via ${router_ip}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now bagitops-use-router.service >/dev/null 2>&1

  echo "Default route set to: ${router_ip}"
}

cmd_cancel_use_router() {
  [[ $EUID -eq 0 ]] || die "cancel-use-router requires root — run with sudo"

  # Restore original default gateway
  if [[ -f "$BAGITOPS_USE_ROUTER_ORIG" ]]; then
    local orig_gw
    orig_gw=$(cat "$BAGITOPS_USE_ROUTER_ORIG")
    if [[ "$orig_gw" != "none" && -n "$orig_gw" ]]; then
      ip route replace default via "$orig_gw"
      echo "Default route restored to: ${orig_gw}"
    else
      ip route del default 2>/dev/null || true
      echo "No original default route — removed custom route."
    fi
    rm -f "$BAGITOPS_USE_ROUTER_ORIG"
  else
    echo "No saved original route found — removing custom route."
    ip route del default 2>/dev/null || true
  fi

  # Remove systemd service
  if systemctl is-active --quiet bagitops-use-router.service 2>/dev/null; then
    systemctl stop bagitops-use-router.service
  fi
  if systemctl is-enabled --quiet bagitops-use-router.service 2>/dev/null; then
    systemctl disable bagitops-use-router.service >/dev/null 2>&1
  fi
  rm -f "$BAGITOPS_USE_ROUTER_SERVICE"
  systemctl daemon-reload

  echo "use-router cancelled."
}
