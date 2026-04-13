FROM node:20-alpine AS builder
WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/api/package.json apps/api/package.json
COPY packages/sdk/package.json packages/sdk/package.json
COPY packages/types/package.json packages/types/package.json

RUN pnpm install --frozen-lockfile

COPY apps/api apps/api
COPY packages/sdk packages/sdk
COPY packages/types packages/types

RUN pnpm --filter @retropick/types build
RUN pnpm --filter @retropick/sdk build
RUN pnpm --filter api build

FROM node:20-alpine AS runner
WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json apps/api/package.json
COPY packages/sdk/package.json packages/sdk/package.json
COPY packages/types/package.json packages/types/package.json

RUN pnpm install --prod --frozen-lockfile --filter api...

COPY --from=builder /app/apps/api/dist apps/api/dist
COPY --from=builder /app/apps/api/node_modules apps/api/node_modules
COPY --from=builder /app/packages/sdk/dist packages/sdk/dist
COPY --from=builder /app/packages/types/dist packages/types/dist

EXPOSE 3001

CMD ["node", "apps/api/dist/main.js"]
