#!/bin/bash

# Start RabbitMQ server in background
rabbitmq-server --detached &

# Wait for server to be ready
until rabbitmqctl status > /dev/null 2>&1; do
  sleep 5
done

# Perform clustering
echo "Attempting to join cluster"
rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@rabbitmq-1
rabbitmqctl start_app

# Wait for the server to be running again after clustering
until rabbitmqctl status > /dev/null 2>&1; do
  sleep 5
done

# Keep the container running
echo "Cluster joined successfully"
tail -f /dev/null