FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash tcl tcllib \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

RUN chmod +x scripts/run-tests.sh

CMD ["./scripts/run-tests.sh"]
