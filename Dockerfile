FROM swift:amazonlinux2 as builder
WORKDIR /swaggerswift
COPY . .

RUN swift package clean
RUN swift build -c release
RUN mkdir /swaggerswift/bin

FROM swift:amazonlinux2-slim
WORKDIR /app
COPY --from=builder /swaggerswift/.build/release/swaggerswift .
ENTRYPOINT ["./swaggerswift"]
