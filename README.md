# TOC

- [Introduction](#introduction)
- [Tools](#tools)
  - [rs](#tools-rs)
- [Usage](#usage)
  - [GitHub Actions](#usage-github-actions)
  - [GitLab Jobs](#usage-gitlab-jobs)
  - [Locally](#usage-locally)
- [Development](#development)
  - [Repository structure](#development-repository-structure)
    - [External consumption](#development-repository-structure-external-consumption)
    - [Tools](#development-repository-structure-tools)
    - [Maintenance](#development-repository-structure-maintenance)
  - [Tests](#development-tests)
  - [Linters](#development-linters)
  - [S3](#development-s3)

# Introduction <a name="introduction"></a>

This repository contains scripts managed and used by
[release-engineering](https://github.com/orgs/paritytech/teams/release-engineering).

# Tools <a name="tools"></a>

## rs <a name="tools-rs"></a>

[`rs`](/rs) (stands for **R**emote **S**torage) is a tool for dealing with
cloud storage platforms such as AWS S3. It offers the following benefits over
using the backends' APIs directly:

- It provides a common interface for different backend APIs.
- It automatically sets the right path for a given file based on the
  `OPERATION` so that users don't have to remember path conventions
  manually.
- Its API is more resilient to breaking changes since arguments can be adapted
  over time according to our needs.

Try `rs --help` for guidance on how to use it.

See https://github.com/paritytech/release-engineering/pull/113 for the
initial concept and motivations.

# Usage <a name="usage"></a>

## GitHub Actions <a name="usage-github-actions"></a>

```yaml
jobs:
  upload-artifact:
    name: My workflow
    runs-on: ubuntu-latest
    steps:
      - name: First step
        run: |
          git clone --depth=1 https://github.com/paritytech/releng-scripts
          ./releng-scripts/foo ...
```

## GitLab Jobs <a name="usage-gitlab-jobs"></a>

```yaml
job:
  script:
    - git clone --depth=1 https://github.com/paritytech/releng-scripts
    - ./releng-scripts/foo ...
```

## Locally <a name="usage-locally"></a>

Clone this repository and run the scripts

# Development <a name="development"></a>

## Repository structure <a name="development-repository-structure"></a>

### External consumption <a name="development-repository-structure-external-consumption"></a>

If a script is meant for external consumption, such as the tools' entrypoints,
then avoid adding file extensions to them since that's more subject to breaking
changes in case we want to change the script's programming language later.
Adding the extension is encouraged for files which are not meant for external
consumption, i.e. scripts which are used only internally or are run through some
command runner such as `just`.

Here's an example:

```
/repository
├── cmd
│  └── rs
│     └── upload.sh
└── rs
```

`rs` is a tool entrypoint meant for external consumption, therefore it doesn't
include an extension. On the other hand, `upload.sh`, which corresponds to the
`upload` subcommand of `rs`, can keep its extension because it's not meant for
external consumption, as it's invoked by `rs`.

### Tools <a name="development-repository-structure-tools"></a>

Tools are organized with the following hierarchy:

- Their entrypoints are located at the root of the repository for
  ease-of-external-consumption's sake.

  Avoid including the extension to those files because that's more subject to
  breaking changes in case we want to change the tool's programming language
  later.

  Please maintain an entry to the tools in `./justfile` for ease-of-use's sake.

- In case the tool has subcommands, they are located at `./cmd/$TOOL/$SUBCOMMAND`

  This is to avoid noisy handling of too many commands within a single file.

Here's an example:

```
/repository
├── cmd
│  └── rs
│     └── upload.sh
└── rs
```

`rs` is the tool's entrypoint and `upload.sh` corresponds to the `upload`
subcommand of `rs`.

### Maintenance <a name="development-repository-structure-maintenance"></a>

The `./tasks` directory groups scripts for tasks related to project maintenance,
such as running linters and tests.

Please maintain an entry to those scripts in `./justfile` for ease-of-use's sake.

## Tests <a name="development-tests"></a>

Run the test: `just tests`

Update the snapshots: `just tests --update`

Delete stale snapshots: `just tests --delete-stale-snapshots`

## Linters <a name="development-linters"></a>

`just linters`

## S3 <a name="development-s3"></a>

For testing out the S3 backend you can use https://github.com/adobe/S3Mock.

Set up the following environment variables:

```
export AWS_ACCESS_KEY_ID=1234567890
export AWS_SECRET_ACCESS_KEY=valid-test-key-ref
export AWS_DEFAULT_REGION=us-east-1
export AWS_BUCKET=test
```

Then run the S3Mock docker:

`docker run -p 9090:9090 -p 9191:9191 -e validKmsKeys=arn:aws:kms:"$AWS_DEFAULT_REGION":"$AWS_ACCESS_KEY_ID":key/"$AWS_SECRET_ACCESS_KEY" -e initialBuckets="$AWS_BUCKET" -t adobe/s3mock:latest`

Then try to upload a file:

`just rs upload custom foo/bar s3 --s3mock tests/fixtures/foo.txt`
