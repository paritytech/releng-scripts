# TOC

- [Introduction](#introduction)
- [Tools](#tools)
  - [Bukt](#tools-bukt)
- [Usage](#usage)
  - [GitHub Actions](#usage-github-actions)
  - [GitLab Jobs](#usage-gitlab-jobs)
  - [Locally](#usage-locally)
- [Development](#development)
  - [Tests](#development-tests)
  - [Linters](#development-linters)
  - [S3](#development-s3)

# Introduction <a name="introduction"></a>

This repository contains scripts managed and used by
[release-engineering](https://github.com/orgs/paritytech/teams/release-engineering).

# Tools <a name="tools"></a>

## Bukt <a name="tools-bukt"></a>

`bukt` is a tool for dealing with cloud storage platforms such as AWS S3. It
offers the following benefits over using the backends' APIs directly:

- It provides a common interface for different backend APIs.
- It automatically sets the right path for a given file based on the
  `OPERATION` so that users don't have to remember path conventions
  manually.
- Its API more resilient to breaking changes since arguments can be adapted over
  time according to our needs.

Try `bukt --help` for guidance on how to use it.

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

`just bukt upload custom foo/bar s3 --s3mock tests/fixtures/foo.txt`
