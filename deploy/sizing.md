# HealthyCode deployment sizing

## 1. Purpose and scope

This document describes the infrastructure factors that should be considered when
deploying HealthyCode for approximately 10,000 package records. It complements
[the deployment instructions](README.md).

The information in this document is classified as follows:

| Classification | Meaning |
|---|---|
| Existing value | Explicitly configured or documented by this repository |
| Architectural consideration | Relationship-based expectation, without benchmark data |
| Benchmark required | Not established locally or upstream and requiring measurement |

This document does not replace testing on the intended production environment. In
particular, CPU, memory, disk, and I/O recommendations are not benchmark validated
unless that evidence is explicitly stated.

## 2. Understanding the 10,000-package workload

A package record from a source such as an SPDX SBOM is not necessarily a distinct
Git repository. The HealthyCode CLI performs these steps:

1. Parses the SPDX SBOM or accepts a single Git repository URL.
2. Converts package download locations into Git repository URLs.
3. Removes duplicate repository URLs.
4. Sends a GrimoireLab collection task for each distinct repository.
5. Waits for GrimoireLab data collection to finish asynchronously.
6. Queries OpenSearch for commit and relevant file events.
7. Calculates HealthyCode metrics for the requested date range.
8. Applies the npm scoring model.
9. Returns package results through ScanCode.io to PurlDB.

Consequently, the workload has the following relation:

```text
10,000 package records
  -> fewer repository URL candidates
  -> repository URL deduplication
  -> distinct Git collection tasks
  -> asynchronous GrimoireLab workers
  -> OpenSearch commit and file events
  -> metric calculation and npm scoring
```

The number of distinct repositories is therefore a required benchmark input. It can
vary because many packages can point to the same upstream repository, while large
monorepositories or repositories containing many packages may also require special
consideration.

## 3. HealthyCode deployment architecture

The current deployment has four cooperating areas:

| Area | Responsibility |
|---|---|
| PurlDB | Health API, package metadata, job requests, result storage, API caching |
| ScanCode.io | Scan worker, pipeline execution, worker concurrency, result transfer |
| HealthyCode CLI | Repository scheduling, OpenSearch queries, metric calculation, scoring |
| GrimoireLab | Repository collection, eventization, scheduling, indexing, identity processing |

GrimoireLab itself contains multiple services:

- GrimoireLab server and API
- GrimoireLab eventizer workers
- GrimoireLab archivist workers
- GrimoireLab usher workers
- SortingHat workers
- MariaDB
- Valkey
- OpenSearch
- Nginx

The deployment repository supplies a Docker Compose file for GrimoireLab:
[`docker-compose-grimoirelab2.yml`](docker-compose/docker-compose-grimoirelab2.yml).
PurlDB and ScanCode.io are installed separately using their own upstream projects and
documentation.

## 4. Component-wise infrastructure breakdown

The following table separates evidence from uncertainty.

| Component | Existing configuration | Architectural considerations | Benchmark required |
|---|---|---|---|
| PurlDB API frontend | No CPU, memory, or replica settings in this repository | Query and cache behavior may grow with API traffic and result reuse | Frontend CPU, memory, concurrency, cache size, API latency |
| PurlDB database | No storage or resource settings in this repository | Stores package metadata and computed health data; growth depends on package and result volume | Database capacity, retention, growth, I/O, backup size |
| ScanCode.io workers | Worker count is configurable through `NUM_WORKERS` | More workers increase collection concurrency, CPU and temporary storage pressure | Workers needed, worker CPU/RAM, queue throughput |
| HealthyCode CLI | Runs in a Python 3.13 container | Metric memory may grow with the event result volume fetched from OpenSearch | Event-batch memory, CPU, temporary output storage |
| GrimoireLab core/API | Docker Compose service without resource limits | Handles API and scheduling requests from the CLI and workers | Core CPU/RAM and API throughput |
| Eventizer workers | Docker Compose service without resource limits | Git collection and event extraction are likely to be computationally significant | Worker CPU/RAM, clone throughput, concurrency |
| Archivist workers | Docker Compose service without resource limits | Sends extracted events to OpenSearch | Worker CPU/RAM, indexing throughput |
| Usher workers | Docker Compose service without resource limits | Manages processing workflows in the GrimoireLab backend | Worker CPU/RAM and queue behavior |
| SortingHat | Docker Compose service without resource limits | Processes contributor identity information | CPU/RAM and database I/O |
| MariaDB | MariaDB 11.4 with named `mariadb_data` volume | Stores GrimoireLab scheduler and application state | Storage growth, RAM, CPU, backup size |
| Valkey | Valkey 8 with named `valkey_data` volume | Stores queue and transient state | Memory sizing, persistence policy, queue peaks |
| OpenSearch | OpenSearch 3, heap `-Xms2g -Xmx2g` | Stores commit and file events; likely persistent-data pressure | Heap allocation, CPU/RAM, per-repository storage and I/O |
| Project file storage | No explicit project clone volume in this Compose file | Repository clones and project work files may persist or accumulate according to upstream worker behavior | Retained clone size and cleanup behavior |
| Container registry | GHCR publishing workflow exists; no storage quota is configured | Image size and version retention determine account or organization storage use | Registry retention and storage growth |

## 5. CPU considerations

No CPU reservation, CPU limit, CPU count, or minimum CPU class is configured in the
HealthyCode deployment repository.

The repository explicitly supports Linux deployment, Docker, and Docker Compose. The
issue requires amd64 CPUs; this is a deployment platform restriction rather than a
validated CPU benchmark.

CPU-sensitive operations are expected to include:

- Git repository cloning and history event extraction.
- GrimoireLab eventization and identity processing.
- OpenSearch indexing and event queries.
- Metric aggregation in the HealthyCode CLI.
- PurlDB API and database work.
- ScanCode.io worker execution and pipeline orchestration.

CPU requirements should not be inferred from package count alone. Repository size,
Git history length, number of branches, number of contributors, event count, clone
speed, worker count, and OpenSearch query volume can dominate CPU consumption.

A suitable CPU allocation and worker concurrency must be established with an actual
representative workload.

## 6. Memory considerations

The existing deployment guidance states a host baseline of **32 GB RAM** and says
that more memory is preferable. This value is documented guidance, not a measured
component allocation.

The OpenSearch Compose service has the only explicit application memory setting:

```text
OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g
```

Other GrimoireLab, MariaDB, Valkey, ScanCode.io, PurlDB, and HealthyCode services have
no memory limit, reservation, or heap setting documented in this repository.

Memory pressure may come from:

- OpenSearch indexing and query buffers.
- GrimoireLab workers processing Git history.
- HealthyCode loading repository events into metric analyzers.
- Concurrent repository collection.
- ScanCode.io worker concurrency.
- Database page caches and transaction buffers.
- Repository clones and temporary extraction directories.

The existing OpenSearch heap is 2 GB, but host memory should not be allocated based
only on this heap. The host must also accommodate all containers and the operating
system.

Peak process memory, container memory limits, and host-level memory pressure require
benchmarking.

## 7. Persistent storage requirements

Persistent storage should be separated by component and purpose.

| Storage area | Existing value or configuration | Scaling consideration |
|---|---|---|
| Base installation | 500 GB guidance for the base installation | Existing documentation; not benchmark validated |
| MariaDB | Named `mariadb_data` volume | Scheduler and application state scale with repository and task history |
| Valkey | Named `valkey_data` volume | Queue and transient state scale with active jobs and persistence settings |
| OpenSearch | Named `opensearch_data` volume | Events scale with repositories, commits, file actions, branches, and retention |
| GrimoireLab repository data | No explicit named clone or project volume identified here | Must be measured against upstream clone and retention behavior |
| PurlDB database | Upstream database, not defined in this repository | Package metadata and health results scale with package count and retention |
| ScanCode.io projects/results | Upstream storage, not defined in this repository | Pipeline project and output retention scale with package scan volume |
| Container registry | GHCR workflow publishes tagged images; no quota is configured | Image count, image size, and retained tags determine registry storage |

For ongoing production, the existing deployment documentation states that more disk
space is required to retain Git clones of tracked projects. The actual clone growth
rate has not been measured in this repository.

Storage sizing should include:

- Filesystem headroom, snapshots, and backups.
- OpenSearch index growth and replacement/merge activity.
- Database retention policies.
- Container image and layer retention.
- Repository cleanup and retention behavior.
- Project and pipeline output retention.

## 8. Temporary storage requirements

Temporary storage differs from persistent storage. It is used only during job or
processing lifetimes, although orphaned files may persist after failures.

Examples include:

- Git clone directories.
- GrimoireLab extraction work directories.
- ScanCode.io pipeline work directories.
- SPDX and JSON files passed between tools.
- Container build and image-layer caches.
- OpenSearch segment and indexing activity.
- Temporary files produced during OpenSearch query processing.

Temporary storage peaks must be measured because a large repository batch can consume
space even when the average retained size is small. ScanCode.io worker concurrency
can multiply peak temporary usage.

The repository does not document temporary directories, cleanup intervals, quotas,
or a minimum temporary-filesystem size.

## 9. Existing deployment baseline

The existing baseline guidance is:

| Resource | Existing documented/configured value | Status |
|---|---|---|
| Host memory | 32 GB; more is better | Existing documentation, not benchmark validated |
| Base disk | 500 GB | Existing documentation, not benchmark validated |
| OpenSearch Java heap | Initial 2 GB, maximum 2 GB | Existing Compose configuration |
| Repository wait timeout | 3600 seconds | Existing CLI default |
| OpenSearch timeout | 30 seconds per connection request | Existing CLI default |
| Repository readiness polling | Every 25 seconds | Existing implementation |
| ScanCode.io workers | Configurable with `NUM_WORKERS` | Existing deployment parameter |

The baseline should be treated as a starting point for installation and testing.
It is not evidence of the minimum, maximum, or optimum allocation for 10,000 packages.

## 10. GrimoireLab worker scaling

GrimoireLab has distinct worker services for event collection, archival, ushering, and
SortingHat processing. The current Compose file does not expose explicit CPU or memory
limits and does not scale most workers horizontally.

Scaling variables to benchmark include:

- Number of GrimoireLab eventizer workers.
- Number of archivist workers.
- Number of ScanCode.io workers.
- OpenSearch ingestion concurrency.
- MariaDB and Valkey capacity.
- Repository batch size.

Collection concurrency may reduce elapsed time but increase peaks in CPU, memory,
network bandwidth, clone storage, and OpenSearch writes. Sequential repository
scheduling by the CLI can become a startup and API queueing bottleneck even if
GrimoireLab workers continue processing asynchronously.

The repository does not prescribe a worker-to-host or worker-to-repository ratio.
Those values require measurement.

## 11. PurlDB and ScanCode.io considerations

PurlDB is responsible for API traffic, package metadata, health-result caching, and
queueing ScanCode.io jobs. The repository does not define PurlDB CPU, memory, database,
or I/O requirements.

ScanCode.io is responsible for worker concurrency and pipeline execution. The existing
deployment documentation configures it with:

```text
--scale worker=${NUM_WORKERS}
```

The value of `NUM_WORKERS` is deployment-specific. Increasing it can improve throughput
while proportionally increasing clone and pipeline workspace pressure, CPU scheduling,
network traffic, and database/queue activity.

Neither PurlDB's nor ScanCode.io's upstream deployment documentation establishes a
supported sizing value for 10,000 packages within this issue. Both require actual
benchmarking in the selected supported versions.

## 12. Repository timeout and date-range considerations

### Repository timeout

The CLI default `--repository-timeout` is **3600 seconds**. This option is a single
global waiting limit for the complete pending repository set in a HealthyCode CLI
execution. It does not mean that every repository gets 3600 seconds.

Repositories that do not become ready before the limit are logged as timed out. The
CLI then continues only with repositories whose collection tasks are considered ready.

Timeout risk can increase when:

- Repository count is high.
- Repository size or history is large.
- Git network access is slow or failing.
- Many workers start at once.
- OpenSearch ingestion is slow.
- A shared host is CPU, memory, or I/O constrained.
- ScanCode.io worker concurrency is too low or too high.

The timeout and queue wait should both be reported in benchmark results.

### OpenSearch timeout and polling

The CLI default `--opensearch-timeout` is **30 seconds** and repository readiness is
checked every **25 seconds**. Repeated polling adds API traffic but is not a substitute
for collection throughput measurement.

### Date range

The CLI defaults to the previous year through today when explicit dates are omitted.
`--from-date` and `--to-date` filter commit and event queries in OpenSearch before
metrics are calculated.

A narrower date range can reduce metric query result volume and in-process aggregation
work. A wider range can increase query volume and memory use for an event-intensive
repository.

Date ranges do not necessarily change repository clone or initial event collection size
in the same way. Collection can store the repository event history before the metric
calculation applies the date filter. The difference should be measured rather than
assumed.

## 13. AMD64 architecture support

Only **amd64** CPUs are supported for the documented deployment.

Operators must verify:

- Host architecture.
- Docker platform.
- Docker image architecture.
- Database and OpenSearch container support for amd64.
- ScanCode.io and PurlDB container support for amd64.

ARM64 and mixed-architecture workers are outside the supported deployment assumption
and must not be reported as equivalent benchmark results.

The HealthyCode Docker image is published as a GHCR container image, but this repository
does not configure an explicit multi-platform image-build matrix. Architecture support
must be verified for each deployment component.

## 14. Benchmarking methodology

Do not claim a sizing recommendation until measurements are collected from a representative
10,000-package workload. The methodology should be reproducible and versioned.

### Test environment record

Record:

| Category | Required details |
|---|---|
| Hardware | CPU model, physical/logical core count, RAM, disk model and interface |
| Architecture | Verify amd64 for every component |
| Operating system | Distribution, version, kernel, filesystem, virtualization or bare-metal |
| Container tools | Docker version, Docker Compose version, container runtime |
| HealthyCode version | Git revision, image tag, image digest, Python version |
| Component versions | PurlDB, ScanCode.io, GrimoireLab image/digest, MariaDB, Valkey, OpenSearch |
| Network | External bandwidth, latency, packet loss, private-network setup |
| Deployment topology | Shared host versus separated hosts, container resource limits, replicas |

### Workload record

Record:

- Number of package records.
- Number of unique repository URLs after deduplication.
- Number of missing or invalid repository URLs.
- Package-to-repository ratio.
- Repository file-size and Git-history distributions.
- Distribution of commits, branches, contributors, and file events.
- Repository count by size band, with deliberately representative min, median, and max cases.
- `--from-date` and `--to-date`.
- `--repository-timeout`.
- `--opensearch-timeout`.
- ScanCode.io `NUM_WORKERS`.
- GrimoireLab worker counts and concurrency.
- Cold start versus warm-cache run.
- Re-run behavior for repositories already present in GrimoireLab and caches.

The representative workload should include package repositories with a range of histories
and sizes. It should not consist only of small repositories or a few duplicated URLs.

### Measurements

Collect before, during, and after the workload:

| Metric | Report |
|---|---|
| CPU | Host total and per-service/container average, peak, and CPU throttling |
| Memory | Host and container peak resident memory, heap usage, swap, page/cache pressure |
| Persistent disk | Disk usage before and after, per-volume growth, open file count |
| Temporary disk | Peak workspace usage, per-worker workspace usage, orphaned files after failure |
| Disk I/O | Read/write throughput, IOPS, queue depth, latency if available |
| Network | Ingress/egress rates, clone transfer, API traffic, OpenSearch traffic |
| Processing | Total elapsed time, queue time, collection time, metric time, API response time |
| Completion | Ready repositories, timed-out repositories, failed repositories, retries |
| Database/cache | PurlDB database growth, queue depth, cache hit rate, database I/O |
| OpenSearch | Index size, indexing rate, query latency, heap usage, merge activity |

Use repeated runs whenever possible. Report median, minimum, maximum, peak, and run
count. Record failures and rerun variance instead of removing outliers.

### Suggested benchmark dimensions

Run controlled combinations rather than one unrepeatable all-at-once test:

1. Small and medium repository subsets.
2. The full 10,000-package workload.
3. At least two worker counts.
4. At least two date ranges, including the default and a narrower operational range.
5. Cold and warm GrimoireLab/OpenSearch states where they are operationally meaningful.

The benchmark procedure should preserve all commands, configuration, raw metrics,
container logs, image identifiers, and workload identifiers so another operator can
repeat it.

## 15. Known limitations and assumptions

- Package count is not repository count.
- Repository clone size and commit history are not documented in a package dataset.
- The existing 32 GB RAM and 500 GB disk guidance has no measured component breakdown.
- OpenSearch 2 GB heap is configured, but no CPU or storage sizing validation exists.
- No CPU or memory limits are configured for GrimoireLab Compose services.
- There is no local benchmark dataset, throughput measurement, or resource report.
- The CLI timeout is global to the pending repository set, not one timeout per repository.
- GrimoireLab `2.x` and OpenSearch compatibility are version-sensitive.
- Upstream PurlDB and ScanCode.io deployment sizing is external to this repository and
  has not been established for 10,000 packages in available HealthyCode documentation.
- Persistent and temporary project storage behavior may differ by upstream component
  and retained-image/cleanup configuration.
- The `amd64` support requirement must be preserved for all benchmarked components.
