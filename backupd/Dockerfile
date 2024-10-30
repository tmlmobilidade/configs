###########################
# Define the base image
###########################
FROM node:20.16-alpine AS base

RUN apk add mongodb-tools
RUN apk add postgresql-client

RUN corepack enable
RUN yarn set version 4.5.1

RUN yarn global add turbo@^2

ENV PROJECT=backupd

###########################
# Builder stage
###########################
FROM base AS pruner

WORKDIR /app

COPY . .

RUN turbo prune --scope=@tmlmobilidade/${PROJECT} --docker

###########################
# Installer stage
###########################
FROM base AS builder

WORKDIR /app

# First install the dependencies (as they change less often)
COPY --from=pruner /app/out/json/ .
RUN yarn install

# Build the project
COPY --from=pruner /app/out/full/ .
RUN turbo run build --filter=@tmlmobilidade/${PROJECT}

# ###########################
# # Runner stage
# ###########################
FROM base AS runner

WORKDIR /app

COPY --from=builder /app .

CMD node ${PROJECT}/dist/index.js
