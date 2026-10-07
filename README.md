# HealthyCode

Open source project health metrics and scores, built on an open model, open
methodology, with open data.

HealthyCode attempts to tell you how healthy an open source projects is, so you
can make more informed, data-driven decisions about which packages to adopt,
upgrade, or replace. HealthyCode collect a project's development history events
(like commits, contributors, and other activities) and turns these into health
"metrics". The metrics are then used to compute a health score using a scoring
procedure where each metrics is weighted, and weights are tuned from a training
data sets. The score is backed by these metrics, enabling to see why a package
scored and how, and to set own policy thresholds.

HealthyCode uses [GrimoireLab](https://github.com/chaoss/grimoirelab) to collect
data, [ScanCode.io](https://github.com/aboutcode-org/scancode.io) to run
pipelines, and [PurlDB](https://github.com/aboutcode-org/purldb) to store the
data.

## Why project health matters

Most software is assembled from open source packages. Security scanners are good
at flagging a package with a known vulnerability, but they say nothing about a
package whose last maintainer has quietly moved on...

> HealthyCode starts with npm. Other ecosystems will follow.
>    

> npm is the largest package registry in the world, and its packages depend on
> each other heavily. A small library can sit underneath thousands of projects.
>

> With npms, this risk can spread quickly as the JavaScript developers prefer
> publishing many smaller packages, and many small unmaintained library can become
> a single point of failure for everything built on it, and are also easier to
> take over. When a maintainer's account or email domain expires, an attacker can
> claim it and publish a malicious release.
  
HealthyCode helps you spot these packages before you depend on them, and helps
you keep watching the ones you already use as dependencies.

## What's provided

For this first iteration, HealthyCode focus is on npm packages. We will extend
support to other ecosystems, and we designed the scording model to be specific
to one open source packaging ecosystem.

Given a PURL (Package-URL) for a package, HealthyCode's API returns:

- Health metrics from the project's Git history, such as recent commits,
contributor activity and growth, days since last commit, pony factor (how many
people do half the work), and the elephant factor (how many organizations do
half the work). The full list is in [METRICS.md](METRICS.md).

- A health score is calculted from the metrics, between 0 and 1 that is the
model's estimate of how likely the project is to be healthy. 0 means unhealthy
or risky, and 1 means healthier and less risky.

- The settings used for the run: time window, thresholds, and the versions of
HealthyCode and the scoring model.

The API results are JSON, so you can pull these into a dashboard, a report, or
in your software supply processing and management pipelines, including policies
to allow or block or alert in your own tooling about the health of a software
page. HealthyCode gives you the evidence, but the policy decision stays with
you.

Here is a sample result for the `pkg:npm/semver` package:  
```json
{
    "purl": "pkg:npm/semver",
    "source_purl": "pkg:github/npm/node-semver",
    "vcs_url": "https://github.com/npm/node-semver.git",
    "scoring_model": "npm-health-0.2",
    "score": 1.0,
    "commit_range": {
        "last_commit": "3484e1785e18a7ae4f06365f35c7b6eaec05088a",
        "first_commit": "a25789b09b1192fa8414c35f2cd679ae2e1d5192",
        "last_commit_date": "2026-09-10T19:51:52+00:00",
        "first_commit_date": "2025-10-07T10:26:26-07:00"
    },
    "run_start_date": "2026-10-07T21:22:06.088852Z",
    "run_end_date": "2026-10-07T21:22:06.799342Z",
    "metrics": {
        "pony_factor": 2,
        "total_commits": 45,
        "recent_commits": 45,
        "active_branches": 10,
        "elephant_factor": 1,
        "file_types_code": 37,
        "commits_per_week": 0.8630136986301369,
        "commits_per_year": 45.0,
        "file_types_other": 61,
        "commits_per_month": 3.6986301369863015,
        "file_types_binary": 0,
        "message_size_mean": 2538.8444444444444,
        "contributor_growth": 5,
        "found_file_license": 1,
        "message_size_total": 114248,
        "total_contributors": 16,
        "found_file_adopters": 0,
        "message_size_median": 593,
        "recent_contributors": 16,
        "total_organizations": 5,
        "recent_organizations": 5,
        "days_since_last_commit": 26,
        "returning_contributors": 0,
        "commit_size_added_lines": 930,
        "contributor_growth_rate": 0.7142857142857143,
        "coefficient_of_variation": 1.0786365421788087,
        "commit_size_removed_lines": 137,
        "commits_over_periods_rate": 1.0,
        "developer_categories_core": 7,
        "developer_categories_casual": 0,
        "developer_categories_regular": 9,
        "casual_regular_contributors_rate": 0.0
    },
    "date_collected": "2026-10-07T21:22:07.178202Z"
}

```

## Who is HealthyCode for?

- Software and engineering teams deciding whether to adopt, upgrade, replace, or
drop a dependency in their codebases

- Open source program offices (OSPO) and software supply chains teams tracking
the packages used in their organization apps, systems and products

- Maintainers who want an outside view of their own project

- Researchers studying open source sustainability

## When not to use HealthyCode

HealthyCode measures or rather approximates an open source project's health. It
does not scan for vulnerabilities or check license compliance or check the
configuration or security posture of a project. For those, see:

- [OpenSSF ScoreCard](https://github.com/ossf/scorecard) for security posture and configuration
- [VulnerableCode](https://github.com/aboutcode-org/vulnerablecode) for vulnerability lookup
- [ScanCode.io](https://github.com/aboutcode-org/scancode.io) to orchestrate scans including health scans
- [ScanCode Toolkit](https://github.com/aboutcode-org/scancode-toolkit) for origin, license, copyright and dependencies
- [PurlDB](https://github.com/aboutcode-org/purldb) that also hosts the health/ API endpoint.
- [ClearlyDefined](https://https://github.com/clearlydefined/) that pre-scans, and curates open source packages.


## Getting started 

You access health data by Package-URL (PURL) using the [PurlDB](https://github.com/aboutcode-org/purldb) /health API.
This is accessible at https://health.purldb.io/api/health for demonstration.
For instance, check https://health.purldb.io/api/health/?purl=pkg:npm/semver or  https://health.purldb.io/api/health/?purl=pkg:npm/lodash
  
You call the health API for a package using its PURL (for example,
`pkg:npm/semver`) and get JSON back. If the package has already been analyzed,
the answer comes back immediately. If not, you can poll the same URL until the
metrics and scores are collected and computed. The request will return first a
"new" status and then a "submitted" status when the job is processed.
The results are cached for a week, and the JSON is returned last.

The processing goes from PurlDB `/health` api endpoint through ScanCode.io
`scan_repo_health` pipeline to the HealthyCode npm-health scoring model (for
now, for npms only), that calls GrimoireLab to collect project metrics.

## Access health data through ScanCode.io pipelines

Run HealthyCode using ScanCode.io `scan_repo_health` next to your other scans:
https://github.com/aboutcode-org/scancode.io/blob/main/scanpipe/pipelines/scan_repo_health.py

That pipeline takes a Git repository URL, collects the data with GrimoireLab,
and saves the metrics and score with the project results. Your ScanCode.io needs
access to a configured GrimoireLab instance and HealthCode models.

## Run HealthCode locally

HealthyCode needs a running [GrimoireLab 2.x](https://github.com/chaoss/grimoirelab/blob/2.x/README.md) with
OpenSearch. GrimoireLab collects the data, and HealthyCode turns the data into metrics
(like the menagerie of ponies and elephants) and computes a score.

The installation, setup, and command-line usage guidance for GrimoireLab is in
[grimoirelab-guide.md]/(grimoirelab-guide.md).


## How Healthy works
1. HealthyCode is given a Git repository URL, or an SPDX SBOM that lists Git repositories.
2. HealthyCode asks GrimoireLab to collect each repository's history. Repositories GrimoireLab hasn't seen yet are added and analyzed.
3. When the data is ready, HealthyCode computes the metrics over a time window. The default is 12 months.
4. The npm health model turns those metrics into a score.
5. The metrics, score, and run settings are written to a JSON file.

#### High-level overview of HealthyCode components

![High-level components of HealthyCode](https://github.com/user-attachments/assets/9fa54e45-a6f9-43b5-8c55-5d7159aa71ed)

#### Drilling down on PurlDB and ScanCode.io 

![PurlDB and ScanCode.io overview](https://github.com/user-attachments/assets/46d2c199-ddbc-43e0-8963-1a438bdcc20a)

#### Drilling down on ScanCode.io + GrimoireLab

![ScanCode.io + GrimoireLab overview](https://github.com/user-attachments/assets/9d5d3bff-1e2d-4be3-8b86-132f02d9151e)


## Methodology for selecting metrics

HealthyCode uses the Goal-Question-Metric (GQM) approach. You start with what
you care about (the goal), then work out what you need to know (the questions),
and only then choose what you can measure (the metrics). 

For example:

- Goal: The project stays maintained
- Question: Would it survive losing its top contributor? 
- Metrics: Pony factor (CHAOSS Contributor Absence Factor aka. "Bus Factor" ),
e.g., top author's share of commits over the last 12 months.

## (npm-health) scoring model

The model was trained on about 1,150 popular npm packages drawn from Census II,
Census III, and deps.dev. As open source experts, we reviewed about 200 of these
npms and classified them as "healthy" or "unhealthy" to create a training
dataset. We computed a logistic regression to determine and learn learned which
metrics best dsicriminate between the two groups and how much weight each metric
would get in the score computation.

All the backing data, the Jupyter notebook, a workflow diagram, and our expert
classifications guidelines are in the [model/npm](model/npm) directory for
reference.

This is a first version and the weights and thresholds will be tuned as more
packages are analyzed; we will define new models fo other ecosystems using the
same approch; and new questions and metrics will be added, drawing on
[CHAOSS](https://www.chaoss.community/),
[OpenSSF Scorecard](https://github.com/ossf/scorecard),
and foundation maturity models.

Eventually we plan to enrich back the [OpenSSF
Scorecard](https://github.com/ossf/scorecard) with these metrics as additionals
checks.


## How this project compares to other approaches and alterives

We have published a review of the state-of-the-art here:
https://aboutcode.org/blog/npm-health-state-of-the-art

People have been working on open source health from these three directions:

1. Organizations improving how they reuse and contribute to open source, through
work such as OpenChain, the FINOS Open Source Maturity Model, the Good
Governance Initiative, and the TODO Group.

2. Open source Foundations grading their own projects, such as the Apache
Software Foundation maturity model, the Eclipse Foundation Development Process,
and the CNCF project lifecycle.

3. Community projects that work across ecosystems, such as the CHAOSS project
that defines open health metrics and models (and where the GrimoireLab projects
lives), and the OpenSSF Scorecard that scores security practices, project
configuration and security posture.

Multiple commercial companies also sell or publish open source package health
scores, but in most cases these are opaque, and you get the score without the
underlying data or weight calculation, making results hard to review, trace or
reproduce.
  
## Most importantly, our results can be audited and traced

The code, the collected data, and the model weights are open and public. Each
score is backed and comed by its supporting metrics; metrics comes from public
project data and history that can be verified.

And you can also rerun the analysis on your own infrastructure to verify, and
reproduce the results. The metrics follow CHAOSS definitions where they exist,
and data collection is run by GrimoireLab, a CHAOSS project.
  
## Project status

HealthyCode is under active development with npm as the first supported
ecosystem. The selected metrics and models will change as more packages are
analyzed, and if a result looks wrong to you, please open an issue with the
Package-URL and a hint of what you expected. That feedback will go directlyinto
improving the model with new and improved training data!

## HealthyCode in the larger AboutCode context

HealthyCode is an initiative that is part of [AboutCode](https://aboutcode.org),
a family of open source tools, open data, and open standards for healthy and
safe software supply chains, together with ScanCode, VulnerableCode, PurlDB,
DejaCode, and Package-URL.
  
You can get results in the PurlDB health API by PURL, the standard package
identifier used in SBOMs and vulnerability databases and across software supply
chains. Exposing the /health endpoint in PurlDB also puts a package's health
data next to its license and origin data collected in PurlDB from ScanCode,
eventually delivering better visibility into the packages from multiple angles.
  
HealthyCode is developed by the AboutCode and GrimoireLab community and
community contributors like you!

## Contributing

Issues and pull requests are welcome.
Please follow the [Code of Conduct](CODE_OF_CONDUCT.rst).
  
Join the [AboutCode community Slack](https://join.slack.com/t/aboutcode-org/shared_invite/zt-31uzazd7l-tBHcqKUKkX6jUEPRLswiNw)
to chat with maintainers, contributors, and users.
 
## License

The code is licensed under GPL-3.0-or-later. See [LICENSE](LICENSE).  
  
Data produced by HealthyCode is licensed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
