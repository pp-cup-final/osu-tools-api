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
# Используем официальный образ ASP.NET Core Runtime от Microsoft,
# в нём уже есть .NET 8 и все системные зависимости.
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runner
WORKDIR /app

# Копируем Node.js из отдельного слоя (в образе .NET его нет).
# Используем slim-версию Node, чтобы не раздувать образ.
COPY --from=node:22-bookworm-slim /usr/local /usr/local
COPY --from=node:22-bookworm-slim /usr/lib/node_modules /usr/lib/node_modules

# node_modules для рантайма (только продакшн-зависимости)
COPY package*.json ./
RUN npm ci --omit=dev

# Собранный TypeScript
COPY --from=ts-builder /app/build ./build

# Собранный C# — ВАЖНО: путь должен совпадать с тем,
# по которому main.js ищет бинарь в рантайме.
# Проверьте свой src/main.ts и при необходимости поправьте путь.
COPY --from=cs-builder /cs-publish ./OsuToolsService/bin/Release/net8.0/publish

EXPOSE 7272
ENV PORT=7272
ENV NODE_ENV=production
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="$PATH:/usr/share/dotnet"

CMD ["node", "build/src/main.js"]