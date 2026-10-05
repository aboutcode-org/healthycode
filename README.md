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