#!/bin/bash

# Define compose files
COMPOSE_FILES=(
  "docker-compose.vm-1.yml"
  "docker-compose.vm-2.yml"
  "docker-compose.vm-3.yml"
  "docker-compose.vm-0.yml"
)

create_network() {
  if ! docker network inspect rabbitmq_network >/dev/null 2>&1; then
    docker network create rabbitmq_network
  fi
}

up() {
  create_network
  echo "Starting containers..."
  for file in "${COMPOSE_FILES[@]}"; do
    docker-compose -f "$file" up -d
  done
}

down() {
  echo "Stopping containers..."
  for file in "${COMPOSE_FILES[@]}"; do
    docker-compose -f "$file" down
  done
  docker network rm rabbitmq_network 2>/dev/null || true
}

restart() {
  down
  up
}

status() {
  docker ps --filter "name=rabbitmq-|nginx" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

case "$1" in
  up)    up ;;
  down)  down ;;
  restart) restart ;;
  status) status ;;
  *)     echo "Usage: $0 {up|down|restart|status}"; exit 1 ;;
esac