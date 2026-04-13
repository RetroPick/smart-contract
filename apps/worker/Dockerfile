FROM node:20-alpine AS builder
WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/worker/package.json apps/worker/package.json
COPY packages/sdk/package.json packages/sdk/package.json
COPY packages/types/package.json packages/types/package.json

RUN pnpm install --frozen-lockfile

COPY apps/worker apps/worker
COPY packages/sdk packages/sdk
COPY packages/types packages/types

RUN pnpm --filter @retropick/types build
RUN pnpm --filter @retropick/sdk build
RUN pnpm --filter worker build

FROM node:20-alpine AS runner
WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/worker/package.json apps/worker/package.json
COPY packages/sdk/package.json packages/sdk/package.json
COPY packages/types/package.json packages/types/package.json

RUN pnpm install --prod --frozen-lockfile --filter worker...

COPY --from=builder /app/apps/worker/dist apps/worker/dist
COPY --from=builder /app/packages/sdk/dist packages/sdk/dist
COPY --from=builder /app/packages/types/dist packages/types/dist

CMD ["node", "apps/worker/dist/main.js"]
