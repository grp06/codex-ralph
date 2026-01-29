FROM node:20-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends git jq ca-certificates curl openssh-client build-essential python3 python3-pip pkg-config ripgrep \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g @openai/codex

WORKDIR /workspace

ENV HOME=/workspace/.ralph/home
ENV CODEX_HOME=/workspace/.ralph/home/.codex

CMD ["bash"]
