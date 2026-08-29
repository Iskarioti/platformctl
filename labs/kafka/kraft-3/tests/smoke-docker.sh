#!/usr/bin/env bash
set -euo pipefail
K=/opt/kafka/bin
docker exec lab-kafka-1 "$K/kafka-topics.sh" \
  --bootstrap-server kafka-1:29092 \
  --create --if-not-exists --topic platformctl-lab \
  --partitions 3 --replication-factor 3 >/dev/null
printf 'hello-platformctl\n' | docker exec -i lab-kafka-1 "$K/kafka-console-producer.sh" \
  --bootstrap-server kafka-1:29092 --topic platformctl-lab >/dev/null
docker exec lab-kafka-2 "$K/kafka-console-consumer.sh" \
  --bootstrap-server kafka-2:29092 --topic platformctl-lab \
  --from-beginning --max-messages 1 --timeout-ms 15000 | grep -q hello-platformctl
echo "PASS kafka-kraft-3 docker smoke"
