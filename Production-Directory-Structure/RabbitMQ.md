## Overview of the Setup
- **VM-1**: Runs `rabbitmq-1` (the cluster leader) in a Docker container, responsible for starting the RabbitMQ server and setting the HA policy.
- **VM-2**: Runs `rabbitmq-2` in a Docker container, joining the cluster led by `rabbitmq-1`.
- **VM-3**: Runs `rabbitmq-3` in a Docker container, also joining the cluster led by `rabbitmq-1`.
- **VM-0**: Runs NGINX in a Docker container, acting as a load balancer for AMQP (port 5675) and the RabbitMQ management UI (port 15675).
- Each VM uses the same configuration files (`start_and_policy.sh`, `join_cluster.sh`, `nginx.conf`) from your local setup, adjusted for the multi-VM network.

---

## Prerequisites
- Four VMs (VM-0, VM-1, VM-2, VM-3) with a supported OS (e.g., Ubuntu 22.04).
- Docker installed on all VMs.
- Network connectivity between VMs.
- Replace `<IP-VM-0>`, `<IP-VM-1>`, `<IP-VM-2>`, and `<IP-VM-3>` with the actual IP addresses of your VMs.

### Install Docker on Each VM
On VM-0, VM-1, VM-2, and VM-3:
```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
```

---

## Step 1: VM-1 (rabbitmq-1)

### Configuration File: `start_and_policy.sh`
- Path: `/opt/rabbitmq/start_and_policy.sh`
- Content:
  ```bash
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
  ```

### Setup Steps
1. **Create Directory and Copy Script**:
   ```bash
   sudo mkdir -p /opt/rabbitmq
   sudo nano /opt/rabbitmq/start_and_policy.sh  # Paste the content above
   sudo chmod +x /opt/rabbitmq/start_and_policy.sh
   ```

2. **Run Docker Container**:
   ```bash
   sudo docker run -d --name rabbitmq-1 \
     --hostname rabbitmq-1 \
     -p 5672:5672 \
     -p 15672:15672 \
     -p 4369:4369 \
     -p 25672:25672 \
     -v /opt/rabbitmq/start_and_policy.sh:/start_and_policy.sh \
     -v /opt/rabbitmq/data:/var/lib/rabbitmq \
     -e RABBITMQ_DEFAULT_USER=admin \
     -e RABBITMQ_DEFAULT_PASS=securepassword \
     -e RABBITMQ_ERLANG_COOKIE=SECURE_COOKIE \
     -e RABBITMQ_NODENAME=rabbit@rabbitmq-1 \
     --restart unless-stopped \
     rabbitmq:3-management /start_and_policy.sh
   ```
   - Ports: Expose AMQP (5672), management UI (15672), Erlang Port Mapper (4369), and clustering (25672).
   - Volume: Persists data in `/opt/rabbitmq/data`.

3. **Prepare Data Directory**:
   ```bash
   sudo mkdir -p /opt/rabbitmq/data
   sudo chown 999:999 /opt/rabbitmq/data  # RabbitMQ user ID in Docker
   ```

---

## Step 2: VM-2 (rabbitmq-2)

### Configuration File: `join_cluster.sh`
- Path: `/opt/rabbitmq/join_cluster.sh`
- Content:
  ```bash
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
  ```

### Setup Steps
1. **Create Directory and Copy Script**:
   ```bash
   sudo mkdir -p /opt/rabbitmq
   sudo nano /opt/rabbitmq/join_cluster.sh  # Paste the content above
   sudo chmod +x /opt/rabbitmq/join_cluster.sh
   ```

2. **Run Docker Container**:
   ```bash
   sudo docker run -d --name rabbitmq-2 \
     --hostname rabbitmq-2 \
     -p 5672:5672 \
     -p 15672:15672 \
     -p 4369:4369 \
     -p 25672:25672 \
     -v /opt/rabbitmq/join_cluster.sh:/join_cluster.sh \
     -v /opt/rabbitmq/data:/var/lib/rabbitmq \
     -e RABBITMQ_DEFAULT_USER=admin \
     -e RABBITMQ_DEFAULT_PASS=securepassword \
     -e RABBITMQ_ERLANG_COOKIE=SECURE_COOKIE \
     -e RABBITMQ_NODENAME=rabbit@rabbitmq-2 \
     --restart unless-stopped \
     rabbitmq:3-management /join_cluster.sh
   ```

3. **Prepare Data Directory**:
   ```bash
   sudo mkdir -p /opt/rabbitmq/data
   sudo chown 999:999 /opt/rabbitmq/data
   ```

---

## Step 3: VM-3 (rabbitmq-3)

### Configuration File: `join_cluster.sh`
- Same as VM-2, reused at `/opt/rabbitmq/join_cluster.sh`.

### Setup Steps
1. **Create Directory and Copy Script**:
   ```bash
   sudo mkdir -p /opt/rabbitmq
   sudo nano /opt/rabbitmq/join_cluster.sh  # Paste the same content as VM-2
   sudo chmod +x /opt/rabbitmq/join_cluster.sh
   ```

2. **Run Docker Container**:
   ```bash
   sudo docker run -d --name rabbitmq-3 \
     --hostname rabbitmq-3 \
     -p 5672:5672 \
     -p 15672:15672 \
     -p 4369:4369 \
     -p 25672:25672 \
     -v /opt/rabbitmq/join_cluster.sh:/join_cluster.sh \
     -v /opt/rabbitmq/data:/var/lib/rabbitmq \
     -e RABBITMQ_DEFAULT_USER=admin \
     -e RABBITMQ_DEFAULT_PASS=securepassword \
     -e RABBITMQ_ERLANG_COOKIE=SECURE_COOKIE \
     -e RABBITMQ_NODENAME=rabbit@rabbitmq-3 \
     --restart unless-stopped \
     rabbitmq:3-management /join_cluster.sh
   ```

3. **Prepare Data Directory**:
   ```bash
   sudo mkdir -p /opt/rabbitmq/data
   sudo chown 999:999 /opt/rabbitmq/data
   ```

---

## Step 4: VM-0 (NGINX)

### Configuration File: `nginx.conf`
- Path: `/opt/nginx/nginx.conf`
- Content:
  ```nginx
  events {
      worker_connections 1024;
  }

  stream {
      upstream rabbitmq_amqp {
          server <IP-VM-1>:5672 max_fails=3 fail_timeout=30s;
          server <IP-VM-2>:5672 max_fails=3 fail_timeout=30s;
          server <IP-VM-3>:5672 max_fails=3 fail_timeout=30s;
      }
      server {
          listen 5675;
          proxy_pass rabbitmq_amqp;
          proxy_connect_timeout 10s;
      }
  }

  http {
      upstream rabbitmq_management {
          server <IP-VM-1>:15672 max_fails=3 fail_timeout=30s;
          server <IP-VM-2>:15672 max_fails=3 fail_timeout=30s;
          server <IP-VM-3>:15672 max_fails=3 fail_timeout=30s;
      }
      server {
          listen 15675;
          location / {
              proxy_pass http://rabbitmq_management;
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection 'upgrade';
              proxy_set_header Host $host;
              proxy_cache_bypass $http_upgrade;
              proxy_connect_timeout 10s;
              proxy_read_timeout 60s;
          }
      }
  }
  ```
  Replace `<IP-VM-1>`, `<IP-VM-2>`, and `<IP-VM-3>` with the actual IPs.

### Setup Steps
1. **Create Directory and Copy Config**:
   ```bash
   sudo mkdir -p /opt/nginx
   sudo nano /opt/nginx/nginx.conf  # Paste the content above
   ```

2. **Run Docker Container**:
   ```bash
   sudo docker run -d --name nginx \
     -p 5675:5675 \
     -p 15675:15675 \
     -v /opt/nginx/nginx.conf:/etc/nginx/nginx.conf \
     --restart unless-stopped \
     nginx:latest
   ```

---

## Step 5: Networking Configuration

### Update `/etc/hosts` on All VMs
To ensure hostname resolution:
```bash
sudo nano /etc/hosts
```
Add:
```
<IP-VM-1> rabbitmq-1
<IP-VM-2> rabbitmq-2
<IP-VM-3> rabbitmq-3
```

### Firewall Rules
Open required ports on each VM:
- **VM-1, VM-2, VM-3**:
  ```bash
  sudo ufw allow 5672    # AMQP
  sudo ufw allow 15672   # Management UI
  sudo ufw allow 4369    # Erlang Port Mapper
  sudo ufw allow 25672   # Clustering
  sudo ufw enable
  ```
- **VM-0**:
  ```bash
  sudo ufw allow 5675    # AMQP via NGINX
  sudo ufw allow 15675   # Management UI via NGINX
  sudo ufw enable
  ```

---

## Step 6: Start and Test the Setup

### Start Sequence
1. **Start VM-1 (rabbitmq-1)**:
   - Run the `docker run` command on VM-1 first to start the cluster leader.
2. **Start VM-2 (rabbitmq-2) and VM-3 (rabbitmq-3)**:
   - Run their respective `docker run` commands after `rabbitmq-1` is up (check logs for "rabbitmq-1 has started").
3. **Start VM-0 (NGINX)**:
   - Run the NGINX container last, once all RabbitMQ nodes are running.

### Verification
1. **Check Logs**:
   - VM-1:
     ```bash
     sudo docker logs rabbitmq-1
     ```
     Look for "HA policy set successfully."
   - VM-2 and VM-3:
     ```bash
     sudo docker logs rabbitmq-2
     sudo docker logs rabbitmq-3
     ```
     Look for "Attempting to join cluster..." and no errors.

2. **Cluster Status**:
   ```bash
   sudo docker exec rabbitmq-1 rabbitmqctl cluster_status
   ```
   Confirm "Running Nodes" lists:
   ```
   rabbit@rabbitmq-1
   rabbit@rabbitmq-2
   rabbit@rabbitmq-3
   ```

3. **HA Policy**:
   ```bash
   sudo docker exec rabbitmq-1 rabbitmqctl list_policies
   ```
   Verify the `ha-all` policy is set.

4. **NGINX Load Balancing**:
   - Access the management UI: `http://<IP-VM-0>:15675` (login: `admin`/`securepassword`).
   - Test AMQP connectivity by connecting a client (e.g., your Python script) to `<IP-VM-0>:5675`.

---

## Step 7: Production Enhancements
- **Security**: Add SSL/TLS for AMQP and the management UI in `nginx.conf`.
- **Monitoring**: Use `docker logs` or the management UI to monitor health.
- **Data Backup**: Back up `/opt/rabbitmq/data` on each VM periodically.

This setup ensures each RabbitMQ node runs in Docker on its own VM, with NGINX on VM-0 providing load balancing, replicating your local setup in a distributed production environment. Let me know if you need further clarification!