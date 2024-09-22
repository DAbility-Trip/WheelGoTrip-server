FROM node:20.17.0-alpine3.20 AS base

# PNPM Setup
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
RUN pnpm config set store-dir /pnpm/store &&\
    pnpm config set package-import-method copy

# Working Directory
WORKDIR /usr/src/app
COPY package.json .
COPY pnpm-lock.yaml .

# Install Dependencies (prod-only)
FROM base AS prod-deps

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm fetch --prod --prefer-offline --ignore-scripts --frozen-lockfile
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prod --prefer-offline --ignore-scripts --frozen-lockfile

# Build
FROM base AS build

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm fetch --prefer-offline --ignore-scripts --frozen-lockfile
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prefer-offline --ignore-scripts --frozen-lockfile

COPY . .

RUN pnpm build

# ======================================================== #
# START Development Image                                  #
# ======================================================== #

# Dev Image
FROM base AS dev

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm fetch --prefer-offline --ignore-scripts --frozen-lockfile
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prefer-offline --ignore-scripts --frozen-lockfile

ENV NODE_ENV=development
COPY . .

ENTRYPOINT pnpm start:dev

# ======================================================== #
# END Development Image                                    #
# ======================================================== #

# ======================================================== #
# START Production Image                                   #
# ======================================================== #

# Production Image
FROM base AS prod

# Install PM2
RUN pnpm add -g pm2

# Copy build & package files
COPY --from=prod-deps /usr/src/app/node_modules /usr/src/app/node_modules
COPY --from=build /usr/src/app/dist /usr/src/app/dist

ENV NODE_ENV=production
COPY .production.env .

ENTRYPOINT pm2-runtime start dist/main.js --name app-prod

# ======================================================== #
# END Production Image                                     #
# ======================================================== #