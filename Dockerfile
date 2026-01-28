# syntax=docker/dockerfile:1.7

ARG CHATWOOT_BASE=chatwoot/chatwoot:v4.8.0-ce

############################################
# Builder
############################################
FROM ${CHATWOOT_BASE} AS builder

ARG RAILS_ENV=production
ARG NODE_ENV=production

WORKDIR /app

# Copy full source from your fork
COPY . /app

# Apply overrides BEFORE build
RUN if [ -d "/app/overrides" ]; then cp -R /app/overrides/* /app/ ; fi

# --- Install Node + npm (base image may not ship with them) ---
RUN set -eux; \
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then \
    echo "Node/npm already present"; \
  elif [ -f /etc/alpine-release ]; then \
    apk add --no-cache nodejs npm; \
  else \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs npm; \
    rm -rf /var/lib/apt/lists/*; \
  fi

# Install pnpm (don't use corepack)
RUN npm i -g pnpm@10.5.2

# Debug versions (makes CI logs obvious)
RUN node -v && npm -v && pnpm -v

# Ruby deps
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# Install JS deps (no pnpm build at root)
RUN pnpm install --frozen-lockfile

# Precompile assets (this is the real "build" for Chatwoot)
RUN bundle exec rails assets:precompile


############################################
# Runtime
############################################
FROM ${CHATWOOT_BASE} AS runtime

ARG VCS_REF=""
ARG BUILD_DATE=""

LABEL org.opencontainers.image.source="https://github.com/saokimdigital/optimax-source" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

WORKDIR /app
COPY --from=builder /app /app
RUN mkdir -p /app/storage
