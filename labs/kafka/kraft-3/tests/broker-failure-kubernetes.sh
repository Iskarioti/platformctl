#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-kafka-kraft-3
K=/opt/kafka/bin
POD="$(kubectl get pod -n "$NS" -l kafka-node=1 -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "$NS" "$POD" -- "$K/kafka-topics.sh" \
  --bootstrap-server kafka-1:29092 \
  --create --if-not-exists --topic platformctl-failover \
  --partitions 3 --replication-factor 3 >/dev/null
kubectl scale deployment/kafka-1 -n "$NS" --replicas=0
trap 'kubectl scale deployment/kafka-1 -n "$NS" --replicas=1 >/dev/null 2>&1 || true' EXIT
sleep 10
POD2="$(kubectl get pod -n "$NS" -l kafka-node=2 -o jsonpath='{.items[0].metadata.name}')"
printf 'after-failure\n' | kubectl exec -i -n "$NS" "$POD2" -- \
  "$K/kafka-console-producer.sh" --bootstrap-server kafka-2:29092 --topic platformctl-failover >/dev/null
POD3="$(kubectl get pod -n "$NS" -l kafka-node=3 -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "$NS" "$POD3" -- "$K/kafka-console-consumer.sh" \
  --bootstrap-server kafka-3:29092 --topic platformctl-failover \
  --from-beginning --max-messages 1 --timeout-ms 15000 | grep -q after-failure
kubectl scale deployment/kafka-1 -n "$NS" --replicas=1
trap - EXIT
echo "PASS kafka-kraft-3 kubernetes broker-failure"
