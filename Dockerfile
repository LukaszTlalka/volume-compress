FROM alpine:latest

RUN apk add --no-cache zip bash findutils && \
    rm -rf /var/cache/apk/*

copy ./src/main.sh /entrypoint.sh

CMD ["./entrypoint.sh"]
