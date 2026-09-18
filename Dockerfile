# --- Этап 1: Сборка (нужны и .NET SDK, и Node.js) ---
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS builder

# Устанавливаем Node.js 22
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN ls -R /src/OsuToolsService/bin 2>/dev/null || echo "no bin dir"
RUN ls -R /src/build 2>/dev/null || echo "no build dir"
COPY . .

# Устанавливаем зависимости и собираем проект целиком
RUN npm ci
RUN npm run build

# --- Этап 2: Финальный образ ---
FROM mcr.microsoft.com/dotnet/runtime:10.0 AS runtime

# Устанавливаем Node.js 22 в финальный образ
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копируем собранные артефакты из builder'а
COPY --from=builder /src/build ./build
COPY --from=builder /src/node_modules ./node_modules
COPY --from=builder /src/package.json ./

# Копируем C#-сервис (путь уточните в репозитории, обычно bin/Release/net10.0/publish)
COPY --from=builder /src/OsuToolsService/bin/Release/net10.0/linux-x64/publish ./OsuToolsService

# Если в репозитории есть proto-файлы или другие ресурсы — скопируйте их тоже
# COPY --from=builder /src/proto ./proto

# Уточните порт в README репозитория (по умолчанию 3000)
EXPOSE 3000

# Уточните команду запуска в package.json (обычно "start" или "node build/index.js")
CMD ["node", "build/index.js"]