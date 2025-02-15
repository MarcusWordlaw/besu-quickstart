#!/bin/bash -eu

# Copyright 2018 ConsenSys AG.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.

NO_LOCK_REQUIRED=false

. ./.env
. ./.common.sh

EXPLORER_SERVICE=explorer
HOST=${DOCKER_PORT_2375_TCP_ADDR:-"localhost"}

# Displays links to exposed services
echo "${bold}*************************************"
echo "Besu Quickstart ${version}"
echo "*************************************${normal}"
echo "List endpoints and services"
echo "----------------------------------"

# Displays services list with port mapping
docker-compose ps
dots=""
maxRetryCount=50
while [ "$(curl -m 10 -s -o /dev/null -w ''%{http_code}'' http://${HOST}:5601/api/status)" != "200" ] && [ ${#dots} -le ${maxRetryCount} ]
do
  dots=$dots"."
  printf "Kibana is starting, please wait $dots\\r"
  sleep 10
done
echo "Setting up the besu index pattern in kibana"
curl -X POST "http://${HOST}:5601/api/saved_objects/index-pattern/besu" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d '{"attributes": {"title": "besu-*","timeFieldName": "@timestamp"}}'

if [ -z `docker-compose -f docker-compose_privacy.yml ps -q orion3` ] || [ -z `docker ps -q --no-trunc | grep $(docker-compose -f docker-compose_privacy.yml ps -q orion3)` ]; then
  echo "Orion not running, skipping the orion index pattern in kibana."
else
  echo "\nSetting up the orion index pattern in kibana"
  curl -X POST "http://${HOST}:5601/api/saved_objects/index-pattern/orion" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d '{"attributes": {"title": "orion-*","timeFieldName": "@timestamp"}}'
fi

# Get individual port mapping for exposed services
explorerMapping=`docker-compose port explorer 80`
explorerPort="${explorerMapping##*:}"
dots=""
maxRetryCount=50
while [ "$(curl -m 10 -s -o /dev/null -w ''%{http_code}'' http://${HOST}:${explorerPort})" != "200" ] && [ ${#dots} -le ${maxRetryCount} ]
do
  dots=$dots"."
  printf "Block explorer is starting, please wait $dots\\r"
  sleep 10
done

echo "****************************************************************"
if [ ${#dots} -gt ${maxRetryCount} ]; then
  echo "ERROR: Web block explorer is not started at http://${HOST}:${explorerPort} !"
  echo "****************************************************************"
else
  echo "JSON-RPC HTTP service endpoint      : http://${HOST}:8545"
  echo "JSON-RPC WebSocket service endpoint : ws://${HOST}:8546"
  echo "GraphQL HTTP service endpoint       : http://${HOST}:8547"
  echo "Web block explorer address          : http://${HOST}:${explorerPort}/"
  echo "Prometheus address                  : http://${HOST}:9090/graph"
  echo "Grafana address                     : http://${HOST}:3000/d/XE4V0WGZz/besu-overview?orgId=1&refresh=10s&from=now-30m&to=now&var-system=All"
  echo "Kibana logs address                 : http://${HOST}:5601/app/kibana#/discover"
  echo "****************************************************************"
fi
