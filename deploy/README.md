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
docker-compose/docker-compose-grimoirelab2.yml

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
production enviroment:

 - For mariadb, set enviroment variables ending in:
   - `*_DB_USER`
   - `*_DB_PASSWORD`

 - For Valkey, set enviroment variables ending in:
   - `*_REDIS_PASSWORD`

## GrimoireLab Startup

Once the initial configutaion above is completed, the next step if launch the
containers with these commands, from a clone of this repository:

```
cd docker-compose/
docker compose -f docker-compose-grimoirelab2.yml up -d
```

## Installation of with PurlDB and ScanCode.io 

### Base installation

The first step is to install PurlDB and ScanCode.io using their standard
documentation.

- Setup PurlDB using code and documentation at https://github.com/aboutcode-org/purldb

Once completed, make sure that PurlDB is up and running.


- Setup ScanCode.io as a PurlDB scan worker using code and documentation at 
https://github.com/aboutcode-org/scancode.io

### Add shared GrimoireLab docker network to ScanCode.io

There is a temaplte for this docker network configuration in:
etc/scancodeio/network.yml. We copy that to the host:

```
cd healthycode-deploy/
sudo cp ./etc/scancodeio/network.yml /etc/scancodeio/network.yml
```

### Edit ScanCode.io systemctl config to run with healthycode profile

```
sudo vi /etc/systemd/system/scancodeio.service
```

Update ExecStart as below:
```
ExecStart=/usr/bin/docker compose \
  -f /opt/scancodeio/docker-compose.purldb-scan-worker.yml \
  -f /etc/scancodeio/networks.yml \
  --profile healthycode \
  up --scale worker=${NUM_WORKERS}
```

```
sudo systemctl daemon-reload
```

### Add PurlDB base URL and API key to ScanCode.io

Get or create a PurlDB API key for the scanworker:
```
# on purldb
docker compose -f /opt/purldb/docker-compose.production.yml exec web python \
  manage_purldb.py create-scan-queue-worker-user <username>
```

```
sudo vi /etc/scancodeio/.env
```

Populate with this config, using localhost assuming eveything is co-located on
one server:
```
PURLDB_URL=
PURLDB_API_KEY="scanworker-api-key"
```

### Configure GrimoireLab environment in ScanCode.io

```
sudo vi /etc/scancodeio/.env
```

Populate with this config:
```
GRIMOIRELAB_URL="http://grimoirelab-nginx:8000/"
GRIMOIRELAB_OPENSEARCH_URL="https://grimoirelab-opensearch:9200/"
GRIMOIRELAB_ECOSYSTEM="npmlargerecosystem"
GRIMOIRELAB_PROJECT="NPMMostUsed"
```

Populate these fields based on the same secret that may have been set in
`./docker-compose/docker-compose-grimoirelab2.yml`

```
GRIMOIRELAB_USERNAME=""
GRIMOIRELAB_PASSWORD=""
GRIMOIRELAB_OPENSEARCH_INDEX=""
GRIMOIRELAB_OPENSEARCH_USERNAME=""
GRIMOIRELAB_OPENSEARCH_PASSWORD=""
```

### Expose ScanCode.io on port 8443

This is optional, and enables access to the ScanCode.io scan worker.
If using this, make sure you configure authentication in ScanCode.io first.

```
sudo vi /opt/scancodeio/.env
```

Add the below env variables:
```
NGINX_PUBLISHED_HTTP_PORT=8081
NGINX_PUBLISHED_HTTPS_PORT=8443
```

### Restart ScanCode.io
```
sudo systemctl restart scancodeio
```

## Verify everything is working end to end


Visit the PurlDB health API at: https://<your host>/api/health/

Make a test request with https://<your host>/api/health/?purl=pkg:npm/lodash&format=json

