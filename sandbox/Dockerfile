# Пісочниця для агентів, які збирають і тестують dopamine-shop: .NET 10 для API і Node 24 для web/admin.
# docker build -t agent-team/dotnet-sandbox:10 sandbox/
FROM node:24-bookworm-slim AS node

FROM mcr.microsoft.com/dotnet/sdk:10.0

ENV DEBIAN_FRONTEND=noninteractive \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

# python3 потрібен OpenClaw для write/edit-хелперів у пісочниці. gh — з репозиторію Ubuntu (образ SDK — Ubuntu 24.04).
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git gh jq python3 ripgrep postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# Node 24 і npm з офіційного образу Node (той самий мажор, що в CI dopamine-shop: .github/workflows/admin.yml).
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && node --version && npm --version

RUN useradd --create-home --shell /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox
CMD ["sleep", "infinity"]
