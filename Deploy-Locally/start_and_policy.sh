#!/bin/bash

# Start RabbitMQ server in the background
rabbitmq-server --detached &

# Wait for the server to be fully ready
until rabbitmqctl status > /dev/null 2>&1; do
  echo "Waiting for rabbitmq-1 to start..."
  sleep 5
done
echo "rabbitmq-1 has started."

# Wait for all nodes to join using built-in command
echo "Waiting for 3 nodes to join the cluster..."
if ! rabbitmqctl await_online_nodes 3 --timeout 300; then
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