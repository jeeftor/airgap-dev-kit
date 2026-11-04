ARG BASE_IMAGE=debian:12-slim
FROM ${BASE_IMAGE}

# Prepare the documented Git prerequisite before disconnecting the container.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 --shell /bin/bash airgap-test \
    && mkdir /work \
    && chown airgap-test:airgap-test /work

USER airgap-test
WORKDIR /work
