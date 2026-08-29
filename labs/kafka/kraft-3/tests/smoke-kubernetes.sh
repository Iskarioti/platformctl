#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-kafka-kraft-3
kubectl wait --for=condition=available deployment/kafka-1 deployment/kafka-2 deployment/kafka-3 -n "$NS" --timeout=240s
POD="$(kubectl get pod -n "$NS" -l kafka-node=1 -o jsonpath='{.items[0].metadata.name}')"
K=/opt/kafka/bin
kubectl exec -n "$NS" "$POD" -- "$K/kafka-topics.sh" \
  --bootstrap-server kafka-1:29092 \
  --create --if-not-exists --topic platformctl-lab \
  --partitions 3 --replication-factor 3 >/dev/null
printf 'hello-platformctl\n' | kubectl exec -i -n "$NS" "$POD" -- \
  "$K/kafka-console-producer.sh" --bootstrap-server kafka-1:29092 --topic platformctl-lab >/dev/null
POD2="$(kubectl get pod -n "$NS" -l kafka-node=2 -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "$NS" "$POD2" -- "$K/kafka-console-consumer.sh" \
  --bootstrap-server kafka-2:29092 --topic platformctl-lab \
  --from-beginning --max-messages 1 --timeout-ms 15000 | grep -q hello-platformctl
echo "PASS kafka-kraft-3 kubernetes smoke"
