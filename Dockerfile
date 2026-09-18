# ---------- Stage 1: собираем C#-сервис ----------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS cs-builder
WORKDIR /app
COPY OsuToolsService/ ./OsuToolsService/
# путь publish-папки зафиксируем, чтобы потом скопировать
RUN dotnet publish -c Release -o /cs-publish ./OsuToolsService/OsuToolsService.csproj

# ---------- Stage 2: собираем TypeScript ----------
FROM node:22-bookworm AS ts-builder
WORKDIR /app

# protoc + bash нужны для scripts/proto-gen.sh
RUN apt-get update && apt-get install -y --no-install-recommends \
        protobuf-compiler bash curl unzip git \
    && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci

COPY . .
RUN bash scripts/proto-gen.sh
RUN npx tsc

# ---------- Stage 3: рантайм ----------
FROM node:22-bookworm-slim AS runner
WORKDIR /app

# .NET runtime — если ваш TS-код спавнит C#-процесс
RUN apt-get update && apt-get install -y --no-install-recommends \
        aspnetcore-runtime-8.0 \
    && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev

# собранный TS
COPY --from=ts-builder /app/build ./build

# собранный C# — ВАЖНО: путь должен совпадать с тем,
# по которому main.js ищет бинарь в рантайме
COPY --from=cs-builder /cs-publish ./OsuToolsService/bin/Release/net8.0/publish

EXPOSE 7272
ENV PORT=7272
ENV NODE_ENV=production

CMD ["node", "build/src/main.js"]