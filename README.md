# Introduction

This repository contains scripts managed and used by [release-engineering](https://github.com/orgs/paritytech/teams/release-engineering).

See the [Tools wiki page](https://github.com/paritytech/releng-scripts/wiki/Tools#TOC) for information on the functionality provided through this repository.

# rs

The commands offerered by `rs` can be access via script, GHS, Docker, etc..
Those use cases are described in the documentation.

The following chapters explain what those commands **are** and how to use them.

You may find convenient testing using:

    alias rs='docker run --rm -it -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION -e AWS_BUCKET paritytech/releng-scripts'

# `rs version`

Get the version:

    docker run --rm -it paritytech/releng-scripts version

output:

    0.0.1

# `rs upload`

Uplooad an artifact.

Check the help with `rs upload --help`

    rs upload --bucket $AWS_BUCKET custom foo/bar s3 tests/fixtures/foo.txt

# `rs download`

Download an artifact.

# `rs delete`

Delete an artifact.

# Reserving crates

1.  Go to <https://github.com/paritytech/releng-scripts/actions/workflows/reserve-crate.yml>

2.  Click the "Run workflow" button to access the workflow’s form

3.  Fill and send the workflow’s form. After that a workflow run
    ([example](https://github.com/paritytech/releng-scripts/actions/runs/3642900863/attempts/1))
    will be created; you might need to refresh the page in order to see it.

4.  Wait for the workflow run to finish

# Usage

## Docker

The image is available as `paritytech/releng-scripts` and usable as:

    # Show the help
    docker run --rm -it paritytech/releng-scripts
    # Show the version
    docker run --rm -it paritytech/releng-scripts version

## GitHub Actions

    jobs:
      upload-artifact:
        name: My workflow
        runs-on: ubuntu-latest
        steps:
          - name: First step
            run: |
              git clone --depth=1 https://github.com/paritytech/releng-scripts
              ./releng-scripts/foo ...

## GitLab Jobs

    job:
      script:
        - git clone --depth=1 https://github.com/paritytech/releng-scripts
        - ./releng-scripts/foo ...

## Locally

Clone this repository and run the scripts

# Contributing

## Repository structure

### External consumption

If a script is meant for external consumption, such as the tools' entrypoints,
then avoid adding file extensions to them since that’s more subject to breaking
changes in case we want to change the script’s programming language later.
Adding the extension is encouraged for files which are not meant for external
consumption, i.e. scripts which are used only internally or are run through some
command runner such as `just`.

Here’s an example:

```
/repository
├── cmd
│  └── releng-scripts
│     └── upload.sh
└── releng-scripts
```

`releng-scripts` is a tool entrypoint meant for external consumption, therefore it doesn't
include an extension. On the other hand, `upload.sh`, which corresponds to the
`upload` subcommand of `releng-scripts`, can keep its extension because it's not meant for
external consumption, as it's invoked by `releng-scripts`.

### Tools

Tools are organized with the following hierarchy:

-   Their entrypoints are located at the root of the repository for
    ease-of-external-consumption’s sake.

        Avoid including the extension to those files because that's more subject to
        breaking changes in case we want to change the tool's programming language
        later.

        Please maintain an entry to the tools in `./justfile` for ease-of-use's sake.

-   In case the tool has subcommands, they are located at `./cmd/$TOOL/$SUBCOMMAND`

        This is to avoid noisy handling of too many commands within a single file.

Here’s an example:

```
/repository
├── cmd
│  └── releng-scripts
│     └── upload.sh
└── releng-scripts
```

`releng-scripts` is the tool's entrypoint and `upload.sh` corresponds to the `upload`
subcommand of `releng-scripts`.

### Maintenance

The `./tasks` directory groups scripts for tasks related to project maintenance,
such as running linters and tests.

Please maintain an entry to those scripts in `./justfile` for ease-of-use’s sake.

## Tests

Run the test: `just tests`

Update the snapshots: `just tests --update`

Delete stale snapshots: `just tests --delete-stale-snapshots`

## Linters

`just linters`

## S3

For testing out the S3 backend you can use [S3Mock](https://github.com/adobe/S3Mock).

Set up the following environment variables:

    export AWS_ACCESS_KEY_ID=1234567890
    export AWS_SECRET_ACCESS_KEY=valid-test-key-ref
    export AWS_DEFAULT_REGION=us-east-1
    export AWS_BUCKET=test

Then start S3Mock:

`./tasks/start-s3-mock.sh`

Then try to upload a file:

`just releng-scripts upload custom foo/bar s3 --s3mock tests/fixtures/foo.txt`
