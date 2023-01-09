#!/usr/bin/env bash

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-1234567890}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-valid-test-key-ref}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
export AWS_BUCKET=${AWS_BUCKET:-test}

docker run -p 9090:9090 -p 9191:9191 \
    -e validKmsKeys=arn:aws:kms:"$AWS_DEFAULT_REGION":"$AWS_ACCESS_KEY_ID":key/"$AWS_SECRET_ACCESS_KEY" \
    -e initialBuckets="$AWS_BUCKET" -t adobe/s3mock:latest
