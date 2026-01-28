# syntax=docker/dockerfile:1.7

ARG CHATWOOT_BASE=chatwoot/chatwoot:v4.8.0-ce

############################################
# 1) Builder: copy source + apply overrides + build assets
############################################
FROM ${CHATWOOT_BASE} AS builder

ARG RAILS_ENV=production
ARG NODE_ENV=production

WORKDIR /app

# Copy the FULL source code of your fork into the image
# (This is the missing piece in your current Dockerfile)
COPY . /app

# Apply overrides BEFORE building assets
# If your overrides live at /overrides in repo root, this will overlay into /app/...
RUN if [ -d "/app/overrides" ]; then \
      cp -R /app/overrides/* /app/ ; \
    fi

# Ensure storage exists (needed by Rails in some setups)
RUN mkdir -p /app/storage

# Install deps and build assets
# Use --frozen-lockfile to ensure reproducible builds
# (If pnpm is not available in base image, see note below)
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# Install pnpm (corepack may not exist in the base image)
RUN node -v && npm -v && npm i -g pnpm@9.12.3

RUN pnpm install --frozen-lockfile && \
    pnpm build

# Precompile Rails assets (this is what makes UI changes appear in production)
RUN bundle exec rails assets:precompile

############################################
# 2) Runtime: keep base image, copy compiled output only
############################################
FROM ${CHATWOOT_BASE} AS runtime

ARG VCS_REF=""
ARG BUILD_DATE=""

LABEL org.opencontainers.image.source="https://github.com/saokimdigital/optimax-source" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

WORKDIR /app

# Copy only what needs to change at runtime:
# - compiled assets
# - updated Ruby/Rails code (if any)
# Easiest safe approach: copy /app from builder (a bit bigger but simplest)
COPY --from=builder /app /app

RUN mkdir -p /app/storage
