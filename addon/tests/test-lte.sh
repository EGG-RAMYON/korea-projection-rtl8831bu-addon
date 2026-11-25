#!/usr/bin/env bash
set -euo pipefail
TMP_AX=$(mktemp -d)
trap 'rm -rf "$TMP_AX"' EXIT
export BB
BB=$(command -v busybox)
export KP_AX_IPT=$TMP_AX/iptables KP_AX_IP6T=$TMP_AX/ip6tables
cat > "$KP_AX_IPT" <<'PY'
#!/usr/bin/env python3
import pathlib, sys
tool = pathlib.Path(sys.argv[0])
chain = tool.with_suffix(".chain")
forward = tool.with_suffix(".forward")
args = sys.argv[1:]
if args == ["-S", "FORWARD"]:
    print("-P FORWARD ACCEPT")
    print(forward.read_text(), end="")
elif args == ["-S", "KP_AX8831"] and chain.exists():
    print("-N KP_AX8831")
    print(chain.read_text(), end="")
elif args == ["-N", "KP_AX8831"] and not chain.exists():
    chain.touch()
elif args == ["-A", "KP_AX8831", "-j", "DROP"]:
    chain.write_text("-A KP_AX8831 -j DROP\n")
elif args[:3] == ["-I", "FORWARD", "1"]:
    forward.write_text("-A FORWARD " + " ".join(args[3:]) + "\n" + forward.read_text())
elif args[:2] == ["-D", "FORWARD"]:
    rule = "-A FORWARD " + " ".join(args[2:]) + "\n"
    if rule not in forward.read_text():
        sys.exit(1)
    forward.write_text(forward.read_text().replace(rule, "", 1))
elif args == ["-F", "KP_AX8831"] and chain.exists():
    chain.write_text("")
elif args == ["-X", "KP_AX8831"] and chain.exists():
    chain.unlink()
else:
    sys.exit(1)
PY
chmod 755 "$KP_AX_IPT"
cp "$KP_AX_IPT" "$KP_AX_IP6T"
for tool in "$KP_AX_IPT" "$KP_AX_IP6T"; do echo '-A FORWARD -j ACCEPT' > "$tool.forward"; done
. "$1"
kp_ax_no_forward
kp_ax_no_forward
for tool in "$KP_AX_IPT" "$KP_AX_IP6T"; do
  [ "$(wc -l < "$tool.forward")" -eq 3 ]
  kp_ax_fwd_top "$tool"
done
kp_ax_clear_forward
for tool in "$KP_AX_IPT" "$KP_AX_IP6T"; do
  [ "$(cat "$tool.forward")" = '-A FORWARD -j ACCEPT' ]
  [ ! -e "$tool.chain" ]
done
rm "$KP_AX_IP6T"
if kp_ax_no_forward; then exit 1; fi
kp_ax_clear_forward
echo 'PASS: IPv4/IPv6 forwarding rules precede ACCEPT, repeat is idempotent, IPv6 failure prevents AP permission, cleanup preserves existing rules'
