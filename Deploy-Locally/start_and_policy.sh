#!/bin/bash

# Start RabbitMQ server in the background
rabbitmq-server --detached &

# Wait for the server to be fully ready
until rabbitmqctl status > /dev/null 2>&1; do
  echo "Waiting for rabbitmq-1 to start..."
  sleep 5
done
echo "rabbitmq-1 has started."

# Wait for all three nodes to join the cluster
COUNTER=0
until [ $COUNTER -ge 30 ] || (nodes=$(rabbitmqctl cluster_status | sed -n '/Running Nodes/,/^$/p' | grep "^rabbit@") && \
      echo "$nodes" | grep -q "rabbit@rabbitmq-1" && \
      echo "$nodes" | grep -q "rabbit@rabbitmq-2" && \
      echo "$nodes" | grep -q "rabbit@rabbitmq-3"); do
  echo "Waiting for rabbitmq-2 and rabbitmq-3 to join... (Attempt $COUNTER)"
  sleep 10
  COUNTER=$((COUNTER + 1))
done

if [ $COUNTER -ge 30 ]; then
  echo "Timeout: Cluster did not form within 5 minutes."
  exit 1
fi
echo "All nodes have joined the cluster."

# Set the HA policy
echo "Setting HA policy for all queues..."
rabbitmqctl set_policy -p / ha-all "^" '{"ha-mode":"all","ha-sync-mode":"automatic"}'
echo "HA policy set successfully."

# Keep the container running
tail -f /dev/null