# syntax=docker/dockerfile:1.7

ARG CHATWOOT_BASE=chatwoot/chatwoot:v4.8.0-ce

############################################
# Builder: Chatwoot base + add Node/pnpm + build assets
############################################
FROM ${CHATWOOT_BASE} AS builder

ENV RAILS_ENV=production \
    NODE_ENV=production \
    HUSKY=0

WORKDIR /app

# Copy full source
COPY . /app

# Apply overrides BEFORE build
RUN if [ -d "/app/overrides" ]; then cp -R /app/overrides/* /app/ ; fi

# Install Node + npm (since base image may not ship with it)
RUN set -eux; \
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then \
    echo "Node/npm already present"; \
  elif [ -f /etc/alpine-release ]; then \
    apk add --no-cache nodejs npm; \
  else \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs npm ca-certificates git; \
    rm -rf /var/lib/apt/lists/*; \
  fi

# Install pnpm 10.x (repo requires engines.pnpm 10.x)
RUN npm i -g pnpm@10.5.2 && pnpm -v && node -v

# JS deps
RUN pnpm install --frozen-lockfile

# Ruby deps (bundle exists in this image)
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# Precompile assets (needs SECRET_KEY_BASE)
RUN SECRET_KEY_BASE=dummy_secret_key_base_for_assets_precompile \
    bundle exec rails assets:precompile

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
