# syntax=docker/dockerfile:1.7

ARG CHATWOOT_BASE=chatwoot/chatwoot:v4.8.0-ce

############################################
# Builder: build assets with source + overrides
############################################
FROM node:20-bullseye AS builder

# Rails env for asset compilation
ENV RAILS_ENV=production \
    NODE_ENV=production \
    # Disable husky in CI/build image
    HUSKY=0

WORKDIR /app

# 1) Copy full source
COPY . /app

# 2) Apply overrides BEFORE build/precompile
# Your overrides structure should be: overrides/app/...
RUN if [ -d "/app/overrides" ]; then cp -R /app/overrides/* /app/ ; fi

# 3) pnpm must be 10.x (repo requires it)
RUN corepack enable && corepack prepare pnpm@10.5.2 --activate
RUN pnpm -v

# 4) Install JS deps (no pnpm build at repo root)
RUN pnpm install --frozen-lockfile

# 5) Install Ruby deps
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# 6) Precompile assets
# Rails requires SECRET_KEY_BASE in production to load environment.
# We set a temporary value ONLY for build-time compilation.
RUN SECRET_KEY_BASE=dummy_secret_key_base_for_assets_precompile \
    bundle exec rails assets:precompile

############################################
# Runtime: keep Chatwoot base + copy compiled app
############################################
FROM ${CHATWOOT_BASE} AS runtime

ARG VCS_REF=""
ARG BUILD_DATE=""

LABEL org.opencontainers.image.source="https://github.com/saokimdigital/optimax-source" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

WORKDIR /app

# Copy everything from builder (simplest + safest)
COPY --from=builder /app /app

# Ensure storage exists
RUN mkdir -p /app/storage
