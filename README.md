# HealthyCode
Open source project health metrics and scores, built on an open model, open methodology, and open data.

HealthyCode tells you how healthy the open source projects you depend on are, so you can make informed, data-driven decisions about which components to adopt, upgrade, or replace. It reads a project's development history (commits, contributors, and how activity changes over time) and turns it into a set of health metrics and one health score. Every score comes with the metrics behind it, so you can see why a package scored the way it did and apply your own thresholds.

HealthyCode uses [GrimoireLab](https://github.com/chaoss/grimoirelab) to collect data, [ScanCode.io](https://github.com/aboutcode-org/scancode.io) to run pipelines, and [PurlDB](https://github.com/aboutcode-org/purldb) to store the data. 

## Why project health matters
Most software is assembled from open source packages. Security scanners are good at flagging a package with a known vulnerability, but they say nothing about a package whose last maintainer has quietly moved on...

> HealthyCode starts with npm. Other ecosystems will follow.
>    
> npm is the largest package registry in the world, and its packages depend on each other heavily. A small library can sit underneath thousands of projects.
>
> In npm, this risk spreads quickly. One unmaintained library can become a single point of failure for everything built on it, and it is also easier to take over. When a maintainer's account or email domain lapses, an attacker can claim it and publish a malicious release. 
  
HealthyCode helps you spot these packages before you depend on them, and keep watching the ones you already use.

## What you get
For each package, HealthyCode returns:
- Health metrics from the project's Git history, such as recent commits, contributor activity and growth, days since last commit, pony factor (how many people do half the work), and the elephant factor (how many organizations do half the work). The full list is in [METRICS.md](METRICS.md).
- A health score between 0 and 1 that is the model's estimate of how likely the project is to be unhealthy. 0 means healthy and 1 means unhealthy.
- The settings used for the run: time window, thresholds, and the versions of HealthyCode and the scoring model.

Results are JSON, so you can feed them into a dashboard, a report, or an allow/block policy in your own tooling. HealthyCode gives you the evidence, but the policy decision stays with you.

Here is a trimmed result for the `semver` package:  
```json
{
    "packages": {
        "SPDXRef-Package-semver-954": {
            "repository": "https://github.com/npm/node-semver.git",
            "metrics": {
                "recent_commits": 52,
                "recent_contributors": 17,
                "returning_contributors": 3,
                "pony_factor": 2,
                "elephant_factor": 1,
                "days_since_last_commit": 1,
                "found_file_license": 1
            },
            "score": {
                "value": 0.0,
                "metadata": {
                    "ecosystem": "npm",
                    "model": "health",
                    "version": "0.2"
                }
            }
        }
    }
}
```

## Who it's for
- Engineering teams deciding whether to adopt, upgrade, replace, or drop a dependency
- Open source program offices (OSPO) and supply chain teams tracking the packages their organization relies on
- Maintainers who want an outside view of their own project
- Researchers studying open source sustainability

## When not to use it
HealthyCode measures project health. It does not scan for vulnerabilities or check license compliance. For those, see [VulnerableCode](https://github.com/aboutcode-org/vulnerablecode), [ScanCode.io](https://github.com/aboutcode-org/scancode.io), and
[ScanCode Toolkit](https://github.com/aboutcode-org/scancode-toolkit).

## Getting started 
HealthyCode needs a running [GrimoireLab 2.x](https://github.com/chaoss/grimoirelab/blob/2.x/README.md)
instance with OpenSearch. GrimoireLab collects the data, and HealthyCode
turns it into metrics and a score.

The quickest way to run HealthyCode is with the published Docker image:

```bash
docker run --rm ghcr.io/aboutcode-org/healthycode:0.2.0 \
  /opt/healthycode/.venv/bin/grimoirelab-metrics \
  https://github.com/npm/node-semver.git \
  --grimoirelab-url http://your-grimoirelab:8000 \
  --grimoirelab-user USER --grimoirelab-password PASSWORD \
  --grimoirelab-ecosystem npm --grimoirelab-project my-packages \
  --opensearch-url https://your-opensearch:9200 \
  --opensearch-user USER --opensearch-password PASSWORD \
  > metrics.json
```

Replace the URLs and credentials with your own. To analyze an SPDX SBOM instead of a single repository, mount the file into the container and pass its path. The first run for a repository takes longer because GrimoireLab has to collect its full history.

Installation, setup, and command-line usage guidance for GrimoireLab is in [grimoirelab-metrics.md]/(grimoirelab-metrics.md).

## How it works
<!-- TODO: add architecture diagrams -->
1. You give HealthyCode a Git repository URL, or an SPDX SBOM that lists Git repositories.
2. HealthyCode asks GrimoireLab to collect each repository's history. Repositories GrimoireLab hasn't seen yet are added and analyzed.
3. When the data is ready, HealthyCode computes the metrics over a time window. The default is 12 months.
4. The npm health model turns those metrics into a score.
5. The metrics, score, and run settings are written to a JSON file.

HealthyCode runs on your own infrastructure. The only outside services it contacts are the public code hosts and registries the data comes from.

## Access health data through ScanCode.io pipelines
You can run HealthyCode from ScanCode.io, next to your other scans: https://github.com/aboutcode-org/scancode.io/blob/main/scanpipe/pipelines/scan_repo_health.py  
  
The `scan_repo_health` pipeline takes a Git repository URL, collects the data with GrimoireLab, and saves the metrics and score with the project results. Your ScanCode.io instance needs access to a GrimoireLab instance to run it.

## Access health data by Package-URL (PURL)
We are adding health data to [PurlDB](https://github.com/aboutcode-org/purldb) via API: https://health.purldb.io/api/  
  
You will be able to ask for a package's health by its PURL (for example, `pkg:npm/semver`) and get the same JSON back. If the package has already been analyzed, the answer comes back right away. If not, the request starts a ScanCode.io pipeline to analyze it. Results will refresh when new versions are released.

## The methodology
HealthyCode uses the Goal-Question-Metric (GQM) approach. You start with what you care about (the goal), then work out what you need to know (the questions), and only then choose what you can measure (the metrics). For example:

| Goal | Question | Metrics |
| --- | --- | --- |
| The project stays maintained | Would it survive losing its top contributor? | Bus factor (CHAOSS Contributor Absence Factor)<br>Top author's share of commits over the last 12 months<br>Time since a second publisher shipped a release |

GitHub stars are not on the list. They answer a question about popularity, and that is not what the model asks.

## The model
The v0.2 model was trained on about 1,150 popular npm packages drawn from Census II, Census III, and deps.dev. An open source expert reviewed 200 and classified 166 as healthy or unhealthy without seeing any scores. A logistic regression then learned which metrics best separate the two groups and how much weight each one gets. The data, notebook, a workflow diagram, and the expert's classifications guidelines are in [model/npm](model/npm).

This is a first version. Weights and thresholds will be tuned as more packages and ecosystems are analyzed, and new questions and metrics will be added, drawing on [CHAOSS](https://www.chaoss.community/), [OpenSSF Scorecard](https://github.com/ossf/scorecard), and foundation maturity models.

## How HealthyCode compares
People have been working on open source health from three directions:
1. Organizations improving how they take in open source, through work such as OpenChain, the FINOS Open Source Maturity Model, the Good Governance Initiative, and the TODO Group.
2. Foundations grading their own projects, such as the Apache Software Foundation maturity model, the Eclipse Foundation Development Process, and the CNCF project lifecycle (sandbox, incubating, graduated, archived).
3. Community projects that work across ecosystems. CHAOSS defines open health metrics and models, and OpenSSF Scorecard scores security practices.

Several commercial companies also sell package health scores. In most cases, you get the score but not the underlying data or the exact weights, which makes a result hard to check or reproduce.

## HealthyCode is open code, open data, , every result can be audited
The code, the collected data, and the model weights are public. Each score comes with the metrics behind it and the settings used to produce it, and each metric comes from public commit history you can check yourself. You can also rerun the analysis on your own infrastructure to verify a result. Metrics follow CHAOSS definitions where they exist, and data collection is done by GrimoireLab, a CHAOSS project.
  
HealthyCode also fits into the AboutCode stack. You can run it as a ScanCode.io pipeline and look up results in PurlDB by PURL, the standard package identifier used in SBOMs and vulnerability databases and across software supply chains. That puts a package's health data next to its license and origin data from ScanCode for more comprehensive visibility into the packages you use.

The full state-of-the-art review is available here: <!-- TODO: link state-of-the-art document -->

## Project status
HealthyCode is at version 0.2.0 and under active development. npm is the first ecosystem, and the metrics and model will change as more packages are analyzed. If a result looks wrong to you, please open an issue with the package name and what you expected. That feedback goes straight into improving the model.

## Part of AboutCode
HealthyCode is part of [AboutCode](https://aboutcode.org), a family of open source tools, open data, and open standards for healthy and secure software supply chains, alongside ScanCode, VulnerableCode, PurlDB, and Package-URL. It is developed by AboutCode and community contributors like you!

## Contributing
Issues and pull requests are welcome. Please follow the [code of conduct](CODE_OF_CONDUCT.rst).
 
## License
The code is licensed under GPL-3.0-or-later. See [LICENSE](LICENSE).  
  
Data produced by HealthyCode is licensed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
