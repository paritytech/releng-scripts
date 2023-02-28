ARG REGISTRY_PATH=docker.io/paritytech

FROM docker.io/library/ubuntu:latest

ARG VCS_REF=master
ARG BUILD_DATE=""
ARG UID=1000
ARG GID=1000
ARG VERSION=0.0.1

LABEL summary="Releng scripts" \
	name="${REGISTRY_PATH}/gnupg" \
	maintainer="devops-team@parity.io" \
	version="${VERSION}" \
	description="Releng scripts" \
	io.parity.image.vendor="Parity Technologies" \
	io.parity.image.source="https://github.com/paritytech/scripts/blob/${VCS_REF}/dockerfiles/releng-scripts/Dockerfile" \
	io.parity.image.documentation="https://github.com/paritytech/scripts/blob/${VCS_REF}/dockerfiles/releng-scripts/README.md" \
	io.parity.image.revision="${VCS_REF}" \
	io.parity.image.created="${BUILD_DATE}"

RUN apt-get update && apt-get install -yq --no-install-recommends ca-certificates bash jq unzip curl && \
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" && \
	unzip "/tmp/awscliv2.zip" && rm "/tmp/awscliv2.zip" && \
	/aws/install && rm -rf /aws && \
	apt -yq remove ca-certificates unzip && apt -yq autoremove && \
	aws --version

WORKDIR /scripts

COPY . .

RUN set -x \
    && groupadd -g $GID nonroot \
    && useradd -u $UID -g $GID -s /bin/bash -m nonroot

USER nonroot:nonroot

ENTRYPOINT [ "./rs" ]
