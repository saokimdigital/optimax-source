# syntax=docker/dockerfile:1.7

ARG CHATWOOT_BASE=chatwoot/chatwoot:v4.8.0-ce
FROM ${CHATWOOT_BASE} AS runtime

ARG VCS_REF=""
ARG BUILD_DATE=""

LABEL org.opencontainers.image.source="https://github.com/saokimdigital/optimax-source" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

WORKDIR /app

# Only overlay customized files (keep base image intact)
COPY overrides/ /app/

# Ensure storage exists
RUN mkdir -p /app/storage
