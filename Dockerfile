# Build du serveur Dart (le moteur est une dépendance locale du monorepo).
FROM dart:3.14 AS build

WORKDIR /app
COPY packages/bellote_engine/ packages/bellote_engine/
COPY server/ server/

WORKDIR /app/server
RUN dart pub get
RUN dart compile exe bin/server.dart -o /app/server/bellote-server

# Image d'exécution légère.
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/server/bellote-server /usr/local/bin/bellote-server

ENV PORT=10000
EXPOSE 10000

CMD ["bellote-server"]
