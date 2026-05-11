FROM alpine:3.22

RUN apk add --no-cache bash tcl tcllib

WORKDIR /app

COPY . .

RUN chmod +x scripts/run-tests.sh

CMD ["./scripts/run-tests.sh"]
