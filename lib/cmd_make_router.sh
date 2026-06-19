#!/usr/bin/env bash
# bagitops make-router / cancel-make-router

BAGITOPS_ROUTER_SYSCTL="/etc/sysctl.d/99-bagitops-router.conf"
BAGITOPS_ROUTER_SERVICE="/etc/systemd/system/bagitops-router.service"

cmd_make_router() {
  [[ $EUID -eq 0 ]] || die "make-router requires root — run with sudo"

  local iface
  iface=$(ip -4 route | awk '/^default/{print $5; exit}')
  [[ -n "$iface" ]] || die "could not detect default network interface"

  echo "Using interface: $iface"

  # Enable IP forwarding now
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  echo "net.ipv4.ip_forward=1" > "$BAGITOPS_ROUTER_SYSCTL"

  # Add iptables rules (idempotent)
  iptables -t nat -C POSTROUTING -o "$iface" -j MASQUERADE 2>/dev/null \
    || iptables -t nat -A POSTROUTING -o "$iface" -j MASQUERADE
  iptables -C FORWARD -j ACCEPT 2>/dev/null \
    || iptables -A FORWARD -j ACCEPT

  # Persist via systemd oneshot service
  cat > "$BAGITOPS_ROUTER_SERVICE" <<EOF
[Unit]
Description=bagitops NAT router
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/iptables -t nat -A POSTROUTING -o ${iface} -j MASQUERADE
ExecStart=/usr/sbin/iptables -A FORWARD -j ACCEPT

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable bagitops-router.service >/dev/null 2>&1

  local vpc_ip
  vpc_ip=$(ip -4 addr show "$iface" | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)

  echo "NAT gateway active."
  echo ""
  echo "  VPC IP (pass this to 'bagitops use-router'): ${vpc_ip}"
}

cmd_cancel_make_router() {
  [[ $EUID -eq 0 ]] || die "cancel-make-router requires root — run with sudo"

  local iface
  iface=$(ip -4 route | awk '/^default/{print $5; exit}')

  # Remove iptables rules (silent if already absent)
  if [[ -n "$iface" ]]; then
    iptables -t nat -D POSTROUTING -o "$iface" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -j ACCEPT 2>/dev/null || true
  fi

  # Revert IP forwarding
  sysctl -w net.ipv4.ip_forward=0 >/dev/null
  rm -f "$BAGITOPS_ROUTER_SYSCTL"

  # Remove systemd service
  if systemctl is-active --quiet bagitops-router.service 2>/dev/null; then
    systemctl stop bagitops-router.service
  fi
  if systemctl is-enabled --quiet bagitops-router.service 2>/dev/null; then
    systemctl disable bagitops-router.service >/dev/null 2>&1
  fi
  rm -f "$BAGITOPS_ROUTER_SERVICE"
  systemctl daemon-reload

  echo "NAT gateway removed."
}
