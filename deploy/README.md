# HealthyCode Deployment documentation

This is the installation documentation for HealthyCode.

It explains how to deploy HealthyCode four components:
- PurlDB frontend
- ScanCode.io worker with its health pipeline and HealthyCode
- GrimoireLab backend

The sequence is to install GrimoireLab, then ScanCode.io and then PurlDB.
The installation assume that we have a Linux installation (Ubuntu or Debian)
with these packages:
 - git
 - docker and docker compose
 - build essentials
 
The machine should have at least 32GB RAM (more is better), and about 500GB
for the base installation. For on-going production, more disk space is required
in order to keep git clones of all the tracked open source projects.


## GrimoireLab installation

This is deployed using the docker compose at:
docker-compose/docker-compose-grimoirelab2.yml


### Set the max_map_count on the server to support OpenSearch needs

GrimoireLab runs a combo of MariaDB, OpenSearch and Valkey(Redis). OpenSearch
needs some specific memory config on the server that runs these containers.

Hence, before we start the OpenSearch container, there is a one time operation
to make sure the Linux server host setting `vm.max_map_count` is set to at least
262144 (instead of the default 65530). Set this value on the host machine as
explained below: 

- Check the current value, with this command:

```
cat /proc/sys/vm/max_map_count
```

- To increase the value, add (or edit) the following line to /etc/sysctl.conf
(using sudo):

```
vm.max_map_count=262144
```

Then run `sudo sysctl -p` to reload the kernel runtime parameters configuration.

### Clone HealthyCode

```
git clone https://github.com/aboutcode-org/healthycode.git /opt/healthycode/ && cd /opt/healthycode/
```

Open `/opt/healthycode/deploy/docker-compose/docker-compose-grimoirelab2.yml` in a text editor,
and set the credentials as suggested in following steps.

### Ports and networks

The main GrimoireLab services needed from outside its docker compose network
are `grimoirelab_core`, served by `nginx` on port 8000` by default and `opensearch`
served on port `9200` by default. Both of the two services are included in a
docker network named `grimoirelab_shared`, and they will be reachable using
these endpoints from inside the docker network:

 - Web server for the GrimoireLab API: http://grimoirelab-nginx:8000/
 - OpenSearch endpoint: https://grimoirelab-opensearch:9200/

### GrimoireLab credentials and authentication

By default healthycode installation does not expose the bulk of GrimoireLab
services outside of the docker network, and therefore we need limited password
on each instance including OpenSearch. ScanCode.io access these through the
private docker network.

There are provisions to set passwords on the various services if needed but
are minimally documented here.

This various values for credentials are configured using environment variables
and defaults in docker compose file at:
`/opt/healthycode/deploy/docker-compose/docker-compose-grimoirelab2.yml`

You can update that file as needed.

#### OpenSearch (aka. archivist)

The GrimoireLab events are stored in OpenSearch cluster.

The credentials for the `admin` user are set with the password variable
`OPENSEARCH_INITIAL_ADMIN_PASSWORD`.

Note that OpenSearch demands a string passwords and will not start up unless
the password is strong. These OpenSearch credentials are the ones needed by the 
`grimoirelab_core_archivists` component. The user is `admin` and the password
is the same you set for OpenSearch:

 - `GRIMOIRELAB_ARCHIVIST_STORAGE_USERNAME`
 - `GRIMOIRELAB_ARCHIVIST_STORAGE_PASSWORD`

#### Scheduler

Set the credentials for the GrimoireLab scheduler and its API. This component is
used by healthycode  to schedule the data collection. Set the following
 variables for the scheduler: 

  - `GRIMOIRELAB_SUPERUSER_USERNAME`
  - `GRIMOIRELAB_SUPERUSER_PASSWORD`

This uses two containers (`valkey` and `maria_db`) that are accessed with
empty credentials through the docker network only.

NOTE that this is not a good practice for production services, yet only
containers inside this compose project can reach them. 

The good practice is to set passwords using the following variables for a
production environment:

 - For mariadb, set environment variables ending in:
   - `*_DB_USER`
   - `*_DB_PASSWORD`

 - For Valkey, set environment variables ending in:
   - `*_REDIS_PASSWORD`

## GrimoireLab Startup

Once the initial configuration above is completed, the next step if launch the
containers with these commands, from a clone of this repository:


```
cd /opt/healthycode/deploy/docker-compose/
docker compose -f docker-compose-grimoirelab2.yml up -d
```

## Installation of PurlDB and ScanCode.io

The first step is to install PurlDB and ScanCode.io using their standard
documentation.

### Install and setup PurlDB

```
git clone https://github.com/aboutcode-org/purldb.git/ /opt/purldb/ && cd /opt/purldb/
make envfile
```

Open `/opt/purldb/.env` in a text editor and populate with this config:

```
ALLOWED_HOSTS=<your host>
SITE_URL=https://<your host>/
PURLDB_PUBLIC_SETUP=True
REST_API_ENDPOINTS=scan_queue,health,packages
```

Build and run PurlDB
```
sudo docker compose -f /opt/purldb/docker-compose.yml build
sudo docker compose -f /opt/purldb/docker-compose.yml up -d
```

Once completed, make sure that PurlDB is up and running.


### Setup  ScanCode.io as a PurlDB scan worker

```
git clone https://github.com/aboutcode-org/scancode.io.git /opt/scancodeio/ && cd /opt/scancodeio/
make envfile
```

#### Add PurlDB base URL and API key to ScanCode.io

Get or create a PurlDB API key for the scanworker:
```
sudo docker compose -f /opt/purldb/docker-compose.yml exec web purldb \
  create-scan-queue-worker-user scancode-worker <username>
```

Copy the scancode-worker API Key, and open `/opt/scancodeio/.env` in a text editor.

```
sudo vi /opt/scancodeio/.env
```

Populate with this config, using localhost assuming everything is co-located on
one server:

```
PURLDB_URL=<your host>
PURLDB_API_KEY="scancode-worker-api-key"
```


#### Configure GrimoireLab environment in ScanCode.io

```
sudo vi /opt/scancodeio/.env
```

Populate with this config:
```
GRIMOIRELAB_URL="http://grimoirelab-nginx:8000/"
GRIMOIRELAB_OPENSEARCH_URL="https://grimoirelab-opensearch:9200/"
GRIMOIRELAB_ECOSYSTEM="npmlargerecosystem"
GRIMOIRELAB_PROJECT="NPMMostUsed"
GRIMOIRELAB_OPENSEARCH_INDEX="events"
```

Populate these fields based on the same secret that may have been set in
`/opt/healthycode/deploy/docker-compose/docker-compose-grimoirelab2.yml`

```
# Populate this using value from GRIMOIRELAB_SUPERUSER_USERNAME
# and GRIMOIRELAB_SUPERUSER_PASSWORD set earlier in
# /opt/healthycode/deploy/docker-compose/docker-compose-grimoirelab2.yml
GRIMOIRELAB_USERNAME=""
GRIMOIRELAB_PASSWORD=""

# Populate this using value from GRIMOIRELAB_ARCHIVIST_STORAGE_USERNAME
# and GRIMOIRELAB_ARCHIVIST_STORAGE_PASSWORD set earlier in
# /opt/healthycode/deploy/docker-compose/docker-compose-grimoirelab2.yml
GRIMOIRELAB_OPENSEARCH_USERNAME=""
GRIMOIRELAB_OPENSEARCH_PASSWORD=""
```

#### Expose ScanCode.io on port 8443

This is optional, and enables access to the ScanCode.io scan worker.
If using this, make sure you configure authentication in ScanCode.io first.

```
sudo vi /opt/scancodeio/.env
```

Add the below env variables:
```
ALLOWED_HOSTS=<your host>
CSRF_TRUSTED_ORIGINS=https://<your host>:8443

NGINX_PUBLISHED_HTTP_PORT=8081
NGINX_PUBLISHED_HTTPS_PORT=8443
```

If this is enabled ScanCode.io will be accessible at: `http://<your host>:8443`


#### Start ScanCode.io

Remove any old healthycode volume.

```
docker volume rm scancodeio_healthycode_venv
```

Pull prebuilt ScanCode docker images

```
sudo docker compose -f /opt/scancodeio/docker-compose.purldb-scan-worker.yml pull
```

Start ScanCode with HealthyCode profile

```
sudo docker compose \
  -f /opt/scancodeio/docker-compose.purldb-scan-worker.yml \
  -f /opt/healthycode/deploy/etc/scancodeio/networks.yml \
  --profile healthycode \
  up --scale worker=2 -d
```

Note: we attach shared GrimoireLab network to ScanCode service using `networks.yml`

## Verify everything is working end to end


Visit the PurlDB health API at: `https://<your host>/api/health/`

Make a test request with `https://<your host>/api/health/?purl=pkg:npm/lodash&format=json`


## Some useful commands

### Start and Stop ScanCode.io service

Start ScanCode.io

```
sudo docker compose \
  -f /opt/scancodeio/docker-compose.purldb-scan-worker.yml \
  -f /opt/healthycode/deploy/etc/scancodeio/networks.yml \
  --profile healthycode \
  up --scale worker=2 -d
```

Stop ScanCode.io:

```
sudo docker compose -f /opt/scancodeio/docker-compose.purldb-scan-worker.yml down
```

### Start and Stop PurlDB service

Start PurlDB:

```
sudo docker compose -f /opt/purldb/docker-compose.yml up -d
```

Stop PurlDB:

```
sudo docker compose -f /opt/purldb/docker-compose.yml down
```

### Start and Stop GrimoireLab service

Start GrimoireLab:

```
docker compose -f /opt/healthycode/deploy/docker-compose/docker-compose-grimoirelab2.yml up -d
```

Stop GrimoireLab:

```
docker compose -f /opt/healthycode/deploy/docker-compose/docker-compose-grimoirelab2.yml down
```


## Enable authentication for ScanCode.io (Optional):

Add this to `/opt/scancodeio/.env`

```
SCANCODEIO_REQUIRE_AUTHENTICATION=True
```

Run this command to create username and password required to login to ScanCode:

```
docker compose -f /opt/scancodeio/docker-compose.yml exec web ./manage.py scanpipe create-user <user-name>
```

Restart ScanCode.io service.

## SSL/TLS Configuration

Add `fullchain.pem` and `privkey.pem` for your host inside:

- /opt/purldb/etc/nginx/conf.d/
- /opt/scancodeio/etc/nginx/conf.d/

Restart PurlDB and ScanCode.io service.

## Reference documentation

- https://scancodeio.readthedocs.io/en/latest/installation.html
- https://purldb.readthedocs.io/en/latest/getting-started/install.html
