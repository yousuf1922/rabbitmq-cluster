#!/bin/bash

# Start RabbitMQ server in background
rabbitmq-server --detached &

# Wait for server to be fully ready
until rabbitmqctl status > /dev/null 2>&1; do
  sleep 5
done

# Allow time for node registration
sleep 20  # Additional buffer

# Perform clustering
echo "Attempting to join cluster..."
rabbitmqctl stop_app
rabbitmqctl reset  # Ensure clean state
if ! rabbitmqctl join_cluster rabbit@rabbitmq-1; then
  echo "Failed to join cluster. Retrying..."
  sleep 10
  rabbitmqctl join_cluster rabbit@rabbitmq-1 || exit 1
fi
rabbitmqctl start_app

# Keep the container running
tail -f /dev/null