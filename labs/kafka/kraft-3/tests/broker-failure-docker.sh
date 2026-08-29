#!/usr/bin/env bash
set -euo pipefail
K=/opt/kafka/bin
docker exec lab-kafka-1 "$K/kafka-topics.sh" \
  --bootstrap-server kafka-1:29092 \
  --create --if-not-exists --topic platformctl-failover \
  --partitions 3 --replication-factor 3 >/dev/null
docker stop lab-kafka-1 >/dev/null
trap 'docker start lab-kafka-1 >/dev/null 2>&1 || true' EXIT
sleep 8
printf 'after-failure\n' | docker exec -i lab-kafka-2 "$K/kafka-console-producer.sh" \
  --bootstrap-server kafka-2:29092 --topic platformctl-failover >/dev/null
docker exec lab-kafka-3 "$K/kafka-console-consumer.sh" \
  --bootstrap-server kafka-3:29092 --topic platformctl-failover \
  --from-beginning --max-messages 1 --timeout-ms 15000 | grep -q after-failure
docker start lab-kafka-1 >/dev/null
trap - EXIT
echo "PASS kafka-kraft-3 docker broker-failure"
