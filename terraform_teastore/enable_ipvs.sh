#!/bin/bash
# enable_ipvs_merged.sh
# Safely enable or revert IPVS mode for kube-proxy on DOKS (or any Kubernetes cluster).
# Usage:
#   ./enable_ipvs_merged.sh          # apply changes
#   ./enable_ipvs_merged.sh --dry-run # show patch but do not apply
#   ./enable_ipvs_merged.sh --revert  # restore latest backup ConfigMap

set -euo pipefail
trap 'rc=$?; rm -f /tmp/kube-proxy-*.yaml /tmp/current-kube-proxy.conf 2>/dev/null || true; exit $rc' EXIT INT TERM

MODE="apply"
if [ "${1:-}" = "--dry-run" ]; then
  MODE="dry-run"
elif [ "${1:-}" = "--revert" ]; then
  MODE="revert"
fi

echo "=== kube-proxy IPVS mode helper ==="
echo "Mode: $MODE"

# 1. Check cluster connectivity
if ! kubectl cluster-info > /dev/null 2>&1; then
  echo "❌ Not connected to a Kubernetes cluster. Aborting."
  exit 1
fi
echo "✅ Connected to cluster."

# 1a. Revert mode
if [ "$MODE" = "revert" ]; then
  echo ""
  echo "Reverting kube-proxy ConfigMap from latest backup..."
  BACKUP_FILE=$(ls -t kube-proxy-cm-backup-*.yaml 2>/dev/null | head -n1 || true)
  if [ -z "$BACKUP_FILE" ]; then
    echo "❌ No backup files found in current directory."
    exit 1
  fi
  echo "   Using backup: $BACKUP_FILE"

  # Verify that the backup file contains either key
  if ! grep -qE 'config\.conf|kube-proxy-config\.yaml' "$BACKUP_FILE"; then
    echo "⚠️  Backup file does not contain expected config keys (config.conf or kube-proxy-config.yaml)."
    exit 1
  fi

  # Replace the ConfigMap
  kubectl apply -f "$BACKUP_FILE" -n kube-system
  echo "✅ ConfigMap restored."

  echo "Restarting kube-proxy..."
  kubectl -n kube-system rollout restart daemonset kube-proxy
  kubectl -n kube-system rollout status daemonset kube-proxy --timeout=300s || true
  echo "=== Revert complete ==="
  exit 0
fi

# 2. Detect current kube-proxy mode robustly
echo ""
echo "2. Detecting current kube-proxy mode..."

CURRENT_MODE=$(kubectl -n kube-system get cm kube-proxy -o jsonpath='{.data.kube-proxy-config\.yaml}' 2>/dev/null \
  | awk '
    /^[[:space:]]*mode:/ {
      gsub(/^[[:space:]]*mode:[[:space:]]*"?/, "", $0)
      gsub(/"?$/, "", $0)
      print $0
      exit
    }
  ' || echo "")

if [ -z "$CURRENT_MODE" ]; then
  CURRENT_MODE="iptables"
fi

echo "   Current kube-proxy mode: $CURRENT_MODE"

if [ "$CURRENT_MODE" = "ipvs" ]; then
  echo "✅ kube-proxy is already running in IPVS mode. Nothing to do."
  exit 0
fi

# 3. Backup the current ConfigMap
echo ""
echo "3. Backing up current kube-proxy ConfigMap..."
BACKUP_FILE="kube-proxy-cm-backup-$(date +%Y%m%d-%H%M%S).yaml"
kubectl -n kube-system get cm kube-proxy -o yaml > "$BACKUP_FILE"
echo "✅ Backup saved to $BACKUP_FILE"

# 4. Prepare IPVS configuration patch (robust for DOKS)
echo ""
echo "4. Preparing IPVS configuration patch..."

# Extract current kube-proxy config
kubectl -n kube-system get cm kube-proxy -o jsonpath='{.data.kube-proxy-config\.yaml}' > /tmp/current-kube-proxy.conf

# detect apiVersion for info
API_VERSION=$(grep -E "^[[:space:]]*apiVersion:" /tmp/current-kube-proxy.conf | awk '{print $2}' || true)
if [ -z "$API_VERSION" ]; then
  API_VERSION="kubeproxy.config.k8s.io/v1alpha1"
  echo "⚠️  Could not detect apiVersion, defaulting to $API_VERSION"
else
  echo "   Detected apiVersion: $API_VERSION"
fi

# Build patch content: replace existing mode or append if missing
PATCH_CONTENT=$(awk '
  BEGIN { mode_set=0 }
  /^[[:space:]]*mode:/ {
    print "    mode: ipvs"
    mode_set=1
    next
  }
  { print "    " $0 }
  END {
    if (mode_set == 0) {
      print "    mode: ipvs"
    }
  }
' /tmp/current-kube-proxy.conf)

# Write patch file
cat > /tmp/kube-proxy-patch.yaml <<EOF
data:
  kube-proxy-config.yaml: |
$PATCH_CONTENT
EOF

echo "   Generated patch:"
cat /tmp/kube-proxy-patch.yaml

if [ "$MODE" = "dry-run" ]; then
  echo ""
  echo "=== DRY-RUN: Patch not applied, kube-proxy not restarted ==="
  exit 0
fi

# 5. Apply patch
echo ""
echo "5. Patching kube-proxy ConfigMap to use IPVS..."
kubectl -n kube-system patch configmap kube-proxy --patch-file /tmp/kube-proxy-patch.yaml
echo "✅ kube-proxy ConfigMap updated."

# 6. Restart kube-proxy
echo ""
echo "6. Restarting kube-proxy DaemonSet..."
kubectl -n kube-system rollout restart daemonset kube-proxy
kubectl -n kube-system rollout status daemonset kube-proxy --timeout=300s || true

# 7. Verify IPVS modules
echo ""
echo "7. Checking if IPVS kernel modules are present (best effort)..."
POD=$(kubectl -n kube-system get pods -l k8s-app=kube-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$POD" ]; then
  if kubectl -n kube-system exec "$POD" -- lsmod 2>/dev/null | grep -q ip_vs; then
    echo "✅ IPVS modules detected on node running $POD"
  else
    echo "⚠️  IPVS modules not detected in node running $POD. kube-proxy may fail to use IPVS."
  fi
else
  echo "⚠️  Could not find a kube-proxy pod to check modules."
fi

# 8. Verify logs
echo ""
echo "8. Verifying IPVS mode in kube-proxy logs..."
PODS=$(kubectl -n kube-system get pods -l k8s-app=kube-proxy -o name || true)
FOUND=false
for p in $PODS; do
  if kubectl -n kube-system logs "$p" --tail=100 2>/dev/null | grep -i -E "ipvs proxier|using ipvs" >/dev/null; then
    echo "✅ IPVS mode confirmed in logs of $p"
    FOUND=true
    break
  fi
done

if [ "$FOUND" = true ]; then
  echo "🎉 kube-proxy is now running in IPVS mode!"
else
  echo "⚠️  Could not confirm IPVS mode in logs. Please check manually:"
  echo "   kubectl -n kube-system logs <kube-proxy-pod> --tail=200 | grep -i ipvs"
fi

echo ""
echo "=== Done ==="
