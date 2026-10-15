# GrimoireLab


Welcome, 

this how-to explains how to deploy the GrimoireLab 2 components.

## Let's get ready

### Requirements

These are the requirements:

 - A Git client
 - Docker Engine and Docker Compose
 - A machine with >= 32GB RAM is recommended

### The max_map_count for OpenSearch

Before we start the OpenSearch container, make sure the Linux setting
`vm.max_map_count` is set to at least 262144. Set this value on the host machine. 

To check the current value, run this command:

```
cat /proc/sys/vm/max_map_count
```

To increase the value, add the following line to /etc/sysctl.conf:

```
vm.max_map_count=262144
```

Then run `sudo sysctl -p` to reload.

### Ports and networks

The main services needed from outside (other docker compose environments)
are grimoirelab_core, served by nginx in the port 8000 by default and opensearch
served by default in the port 9200. Both services are included in a docker network
named `grimoirelab_shared`, they will be reachable using these endpoints

 - web server for the GrimoireLab API: http://grimoirelab-nginx:8000/
 - OpenSearch endpoint: https://grimoirelab-opensearch:9200/


### Credentials

Where are the credentials you need to connect to the GrimoireLab scheduler and the
data?

The events used by grimoirelab-metrics are stored in an opensearch cluster. The
credentials for the `admin` user are set with the password variable `OPENSEARCH_INITIAL_ADMIN_PASSWORD`.
Be careful, OpenSearch does not like weak passwords and will not start up unless the
password is strong. These OpenSearch credentials are the ones needed by the 
`grimoirelab_core_archivists` component. The user should be `admin` and the password,
the same you set for OpenSearch:

 - `GRIMOIRELAB_ARCHIVIST_STORAGE_USERNAME`
 - `GRIMOIRELAB_ARCHIVIST_STORAGE_PASSWORD`

Set the credentials for the scheduler and its API. This component is used by grimoirelab-metrics 
to schedule the data collection. Set the following variables for the scheduler: 

  - `GRIMOIRELAB_SUPERUSER_USERNAME`
  - `GRIMOIRELAB_SUPERUSER_PASSWORD`

There are two containers (`valkey` and `maria_db`) that are accessed with empty credentials.
This is not a good practice for production services, but only containers inside this compose
project can reach them. In any case, as a good practice the following variables should be
set for a production enviroment:

 - For mariadb, the ones ending in:
   - `*_DB_USER`
   - `*_DB_PASSWORD`

 - For Valkey, the ones ending in:
   - `*_REDIS_PASSWORD`

## Deploy

If you are reaching this point, everything is ready to launch the containers. Execute

```
cd docker-compose/
docker compose -f docker-compose-grimoirelab2.yml up -d
```

# Integration with PurlDB and ScanCode.io

- Setup PurlDB https://github.com/aboutcode-org/purldb-deploy
- Setup ScanCode.io as PurlDB scan worker https://github.com/aboutcode-org/scancode.io-deploy

### 1. Add shared GrimoireLab docker network for ScanCode.io

```
cd healthycode-deploy/
sudo cp ./etc/scancodeio/network.yml /etc/scancodeio/network.yml
```

### 2. Edit ScanCode.io systemctl config to run with healthycode profile

```
sudo vi /etc/systemd/system/scancodeio.service
```

Update ExecStart as below:
```
ExecStart=/usr/bin/docker compose -f /opt/scancodeio/docker-compose.purldb-scan-worker.yml -f /etc/scancodeio/networks.yml --profile healthycode  up --scale worker=${NUM_WORKERS}
```

```
sudo systemctl daemon-reload
```
### 3. Add PurlDB URL and API key in ScanCode.io

Get an PurlDB scanworker API key
```
# on purldb
docker compose -f /opt/purldb/docker-compose.production.yml exec web python manage_purldb.py create-scan-queue-worker-user <username>
```

```
sudo vi /etc/scancodeio/.env
```
Populate with below config
```
PURLDB_URL=
PURLDB_API_KEY="scanworker-api-key"
```

### 4. Configure GrimoireLab env in ScanCode.io

```
sudo vi /etc/scancodeio/.env
```
Populate with below config as is:
```
GRIMOIRELAB_URL="http://grimoirelab-nginx:8000/"
GRIMOIRELAB_OPENSEARCH_URL="https://grimoirelab-opensearch:9200/"
GRIMOIRELAB_ECOSYSTEM="npmlargerecosystem"
GRIMOIRELAB_PROJECT="NPMMostUsed"
```

Populate below field based on secret set in ``./docker-compose/docker-compose-grimoirelab2.yml``
```
GRIMOIRELAB_USERNAME=""
GRIMOIRELAB_PASSWORD=""
GRIMOIRELAB_OPENSEARCH_INDEX=""
GRIMOIRELAB_OPENSEARCH_USERNAME=""
GRIMOIRELAB_OPENSEARCH_PASSWORD=""
```

### 5. Expose ScanCode.io on port 8443
```
sudo vi /opt/scancodeio/.env
```

Add the below env variables:
```
NGINX_PUBLISHED_HTTP_PORT=8081
NGINX_PUBLISHED_HTTPS_PORT=8443
```

### 6. Restart ScanCode.io
