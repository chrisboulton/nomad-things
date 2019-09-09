# Nomad + Consul Connect (Envoy)

```sh
#!/bin/bash
set -x
set -e

mkfs.ext4 /dev/disk/by-id/google-data
echo "/dev/disk/by-id/google-data /mnt ext4 rw,rw,discard,errors=remount-ro 0 0" >> /etc/fstab
mount /mnt

apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common \
    wget \
    unzip

cd /tmp
wget -O consul.zip https://releases.hashicorp.com/consul/1.6.0/consul_1.6.0_linux_amd64.zip
unzip consul.zip
mv consul /usr/local/bin/consul
chmod +x /usr/local/bin/consul

mkdir -p /mnt/consul /etc/consul

rm nomad.zip nomad
wget -O nomad.zip https://releases.hashicorp.com/nomad/0.10.0-beta1/nomad_0.10.0-beta1_linux_amd64.zip
unzip nomad.zip
mv nomad /usr/local/bin/nomad
chmod +x /usr/local/bin/nomad

# configure consul

echo '
server = true
ui = true
datacenter = "dc1"
enable_script_checks = true
enable_syslog = true
leave_on_terminate = true
data_dir = "/mnt/consul"
retry_join = [
  "provider=gce tag_value=thinger zone_pattern=us-central1-.*"
]
client_addr = "0.0.0.0"
bootstrap_expect = 3
advertise_addr = "{{ GetInterfaceIP \"enp0s4\" }}"
ports {
  grpc = 8502
}
connect {
  enabled = true
}
enable_central_service_config = true
' > /etc/consul/config.hcl

echo '[Unit]
Description="HashiCorp Consul - A service mesh solution"
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul/config.hcl

[Service]
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/consul.service

systemctl enable consul.service
systemctl daemon-reload
systemctl start consul.service

# docker

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

curl -L -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.1/cni-plugins-linux-amd64-v0.8.1.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

# configure nomad

mkdir -p /mnt/nomad /etc/nomad

echo '
datacenter = "dc1"
data_dir = "/mnt/nomad"
server {
  enabled = true
  bootstrap_expect = 3
}

client {
  enabled = true
}

consul {
  address = "127.0.0.1:8500"
}
' > /etc/nomad/config.hcl

echo '[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/nomad.service

systemctl enable nomad.service
systemctl daemon-reload
systemctl start nomad.service
```
