# Пісочниця для агентів, які збирають і тестують dopamine-shop.
# docker build -t agent-team/dotnet-sandbox:10 sandbox/
FROM mcr.microsoft.com/dotnet/sdk:10.0

ENV DEBIAN_FRONTEND=noninteractive \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

# python3 потрібен OpenClaw для write/edit-хелперів у пісочниці. gh — з репозиторію Ubuntu (образ SDK — Ubuntu 24.04).
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git gh jq python3 ripgrep postgresql-client \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox
CMD ["sleep", "infinity"]
