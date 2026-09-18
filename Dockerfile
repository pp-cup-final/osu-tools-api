# ---------- Stage 1: собираем C#-сервис ----------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS cs-builder
WORKDIR /app
COPY OsuToolsService/ ./OsuToolsService/
COPY proto/ ./proto/
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

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates libicu72 libssl3 zlib1g \
    && curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && bash /tmp/dotnet-install.sh --channel 10.0 --runtime aspnetcore --install-dir /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet \
    && rm /tmp/dotnet-install.sh \
    && rm -rf /var/lib/apt/lists/*

ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="$PATH:/usr/share/dotnet"

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=ts-builder /app/build ./build
COPY --from=cs-builder /cs-publish ./OsuToolsService/bin/Release/net10.0/publish

EXPOSE 7272
ENV PORT=7272
ENV NODE_ENV=production

CMD ["node", "build/src/main.js"]