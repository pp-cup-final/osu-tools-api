# --- Этап 1: Сборка C#-сервиса ---
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS dotnet-builder
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app/publish

# --- Этап 2: Сборка Node.js API ---
FROM node:22-alpine AS node-builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- Этап 3: Финальный образ ---
FROM mcr.microsoft.com/dotnet/runtime:10.0 AS runtime
WORKDIR /app

# Устанавливаем Node.js в финальный образ
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Копируем собранный C#-сервис
COPY --from=dotnet-builder /app/publish ./dotnet-service

# Копируем Node.js API и зависимости
COPY --from=node-builder /app/dist ./dist
COPY --from=node-builder /app/node_modules ./node_modules
COPY --from=node-builder /app/package.json ./

# Открываем порт, который слушает Node.js API (уточните в репозитории)
EXPOSE 3000

# Команда запуска (уточните в package.json репозитория)
CMD ["node", "dist/index.js"]