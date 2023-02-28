# TOC

- [Introduction](#introduction)
- [Reserving crates](#reserving-crates)
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

See the [Tools wiki page](https://github.com/paritytech/releng-scripts/wiki/Tools#TOC) for information on the functionality provided through this repository.

# Reserving crates <a name="reserving-crates"></a>

1. Go to https://github.com/paritytech/releng-scripts/actions/workflows/reserve-crate.yml
2. Click the "Run workflow" button to access the workflow's form
3. Fill and send the workflow's form. After that a workflow run
  ([example](https://github.com/paritytech/releng-scripts/actions/runs/3642900863/attempts/1))
  will be created; you might need to refresh the page in order to see it.
4. Wait for the workflow run to finish

# Usage <a name="usage"></a>

## Docker

The image is available as `paritytech/releng-scripts` and usable as:

```bash
# Show the help
docker run --rm -it paritytech/releng-scripts
# Show the version
docker run --rm -it paritytech/releng-scripts version
```

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

Then start S3Mock:

`./tasks/start-s3-mock.sh`

Then try to upload a file:

`just rs upload custom foo/bar s3 --s3mock tests/fixtures/foo.txt`
