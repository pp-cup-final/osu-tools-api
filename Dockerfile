# ---------- Stage 1: собираем C#-сервис ----------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS cs-builder
WORKDIR /app
COPY OsuToolsService/ ./OsuToolsService/
RUN dotnet publish -c Release -o /cs-publish ./OsuToolsService/OsuToolsService.csproj

# ---------- Stage 2: собираем TypeScript ----------
FROM node:22-bookworm AS ts-builder
WORKDIR /app

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

# .NET 8 Runtime (ASP.NET Core) — ставим через официальный скрипт Microsoft.
# Ставим именно ASP.NET Core runtime, потому что C#-сервис, скорее всего,
# использует gRPC-хостинг из ASP.NET Core.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates libicu72 libssl3 zlib1g \
    && curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && bash /tmp/dotnet-install.sh --channel 8.0 --runtime aspnetcore --install-dir /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet \
    && rm /tmp/dotnet-install.sh \
    && rm -rf /var/lib/apt/lists/*

ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="$PATH:/usr/share/dotnet"

# Прод-зависимости
COPY package*.json ./
RUN npm ci --omit=dev

# Собранный TypeScript
COPY --from=ts-builder /app/build ./build

# Собранный C# — путь должен совпадать с тем, где main.js ищет бинарь.
# Проверьте src/main.ts и при необходимости поправьте левую часть.
COPY --from=cs-builder /cs-publish ./OsuToolsService/bin/Release/net8.0/publish

EXPOSE 7272
ENV PORT=7272
ENV NODE_ENV=production

CMD ["node", "build/src/main.js"]