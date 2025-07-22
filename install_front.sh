#!/bin/bash

chmod -R 777 /home/sadmin
cd /home/sadmin 
apt update && apt upgrade -y
apt install -y nginx
apt install -y apache2
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/apache2/sites-enabled/*
cp nginx/default /etc/nginx/sites-enabled
cp www/html/index.html /var/www/html
cp -r www/html1 /var/www
cp -r www/html2 /var/www
systemctl restart nginx.service
cp apache2/ports.conf /etc/apache2
cp apache2/sites-available/* /etc/apache2/sites-available/
cd /etc/apache2/sites-enabled
rm *
ln -s ../sites-available/000-default.conf 000-default.conf
ln -s ../sites-available/001-default.conf 001-default.conf
ln -s ../sites-available/002-default.conf 002-default.conf
systemctl restart apache2
systemctl enable --now nginx.service
systemctl restart nginx.service
systemctl enable apache2 
cd /home/sadmin/
NODE_EXPORTER_VERSION="1.6.1"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
sudo useradd --no-create-home --shell /bin/false node_exporter
wget $NODE_EXPORTER_URL
tar xvfz node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
PROMETHEUS_VERSION="2.47.0"
PROMETHEUS_URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
sudo useradd --no-create-home --shell /bin/false prometheus
wget $PROMETHEUS_URL
tar xvfz prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus \
       prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles \
           prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus/
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
PKG_DIR="/home/sadmin"
sudo apt-get install -y apt-transport-https software-properties-common wget
sudo wget https://dl.grafana.com/oss/release/grafana_10.4.1_amd64.deb
sudo apt-get update
sudo dpkg -i "${PKG_DIR}/grafana_10.4.1_amd64.deb"
sudo apt-get install -f -y
sudo apt-get install -y apt-transport-https software-properties-common wget
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
dpkg -i "${PKG_DIR}/elasticsearch-8.9.1-amd64.deb"
cat > /etc/elasticsearch/elasticsearch.yml <<EOL
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

xpack.security.enabled: false
xpack.security.enrollment.enabled: true

xpack.security.http.ssl:
  enabled: false
  keystore.path: certs/http.p12

xpack.security.transport.ssl:
  enabled: false
  verification_mode: certificate
  keystore.path: certs/transport.p12
  truststore.path: certs/transport.p12
# cluster.initial_master_nodes: ["elk"]
discovery.type: single-node

http.host: 0.0.0.0
EOL
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch
dpkg -i "${PKG_DIR}/kibana-8.9.1-amd64.deb"
cat > /etc/kibana/kibana.yml <<EOL
server.port: 5601
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://192.168.0.51:9200"]
EOL
systemctl enable kibana
systemctl start kibana
dpkg -i "${PKG_DIR}/filebeat-8.9.1-amd64.deb"
filebeat modules enable nginx
cat > /etc/filebeat/modules.d/nginx.yml <<EOL
- module: nginx
  access:
    enabled: true
    var.paths: ["/var/log/nginx/access.log*"]
  error:
    enabled: true
    var.paths: ["/var/log/nginx/error.log*"]
EOL
cat > /etc/filebeat/filebeat.yml <<EOL
filebeat.inputs:
- type: filestream
  enabled: false

filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: false

setup.template.settings:
  index.number_of_shards: 1

output.elasticsearch:
  hosts: ["192.168.0.51:9200"]

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
EOL
filebeat setup --dashboards
systemctl enable filebeat
systemctl start filebeat
apt-get moo
