#!/usr/bin/env bash

set -e

until [[ -f /var/lib/cloud/instance/boot-finished ]]; do
  sleep 1
done

sudo apt-get update
sudo apt-get -y install git sqlite3 xz-utils curl net-tools tcpdump traceroute iputils-ping jq wget
wget https://dl.gitea.io/gitea/1.16.9/gitea-1.16.9-linux-amd64.xz -P /tmp
wget https://dl.gitea.io/gitea/1.16.9/gitea-1.16.9-linux-amd64.xz.asc -P /tmp
gpg --keyserver keys.openpgp.org --recv 7C9E68152594688862D62AF62D9AE806EC1592E2
gpg --verify /tmp/gitea-1.16.9-linux-amd64.xz.asc /tmp/gitea-1.16.9-linux-amd64.xz
xz --decompress /tmp/gitea-1.16.9-linux-amd64.xz
sudo adduser \
    --system \
    --shell /bin/bash \
    --gecos 'Git Version Control' \
    --group \
    --disabled-password \
    --home /home/git \
    git
sudo mv /tmp/gitea-1.16.9-linux-amd64 /usr/local/bin/gitea
sudo chmod +x /usr/local/bin/gitea
sudo mkdir -p /var/lib/gitea/{custom,data,log}
sudo chown -R git:git /var/lib/gitea/
sudo chmod -R 750 /var/lib/gitea/
sudo mkdir /etc/gitea
sudo chown root:git /etc/gitea
sudo chmod 770 /etc/gitea
sudo mkdir -p /var/lib/gitea/custom/conf
export GITEA_CUSTOM=/var/lib/gitea/custom/
sudo cp /tmp/userdata/app.ini /var/lib/gitea/custom/conf/app.ini
sudo chown git:git /var/lib/gitea/custom/conf
sudo chown git:git /var/lib/gitea/custom/conf/app.ini
sudo chmod 750 /var/lib/gitea/custom/conf
sudo chmod 640 /var/lib/gitea/custom/conf/app.ini
sudo ln -s /var/lib/gitea/custom/conf/app.ini /etc/gitea/app.ini
sudo chown root:git /etc/gitea/app.ini
sudo chmod 750 /etc/gitea
sudo chmod 640 /etc/gitea/app.ini
sudo wget https://raw.githubusercontent.com/go-gitea/gitea/main/contrib/systemd/gitea.service -P /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now gitea
sleep 5
sudo -u git gitea admin user create --username gitea --password Volterra123! --email gitea@example.com -c /var/lib/gitea/custom/conf/app.ini
sudo -u git gitea generate secret INTERNAL_TOKEN -c /var/lib/gitea/custom/conf/app.ini
sudo -u git gitea generate secret JWT_SECRET -c /var/lib/gitea/custom/conf/app.ini
sudo -u git gitea generate secret SECRET_KEY -c /var/lib/gitea/custom/conf/app.ini
TOKEN=$(curl --silent -X POST -H "Content-Type: application/json" -k -d '{"name": "gitea"}' -u gitea:Volterra123! http://127.0.0.1:3000/api/v1/users/gitea/tokens | jq -r .sha1)
curl -k -X POST \
  "http://localhost:3000/api/v1/user/repos" \
  -H "content-type: application/json" \
  -H "Authorization: token $TOKEN" \
  -d '{
  	"name":"awaf",
  	"auto_init": true
  }'
CONTENT=$(cat /tmp/userdata/waf_policy.json | base64)
JSON_FMT='{"author": {"email": "gitea@example.com", "name": "gitea"}, "branch": "master", "committer": {"email": "gitea@example.com", "name": "gitea"}, "content": "%s", "message": "Initial commit of AWAF Policy"}'
PAYLOAD=$(printf "$JSON_FMT" "$CONTENT")
curl -X 'POST' \
  "http://localhost:3000/api/v1/repos/gitea/awaf/contents/waf_policy.json" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: token $TOKEN" \
  -d "$PAYLOAD"