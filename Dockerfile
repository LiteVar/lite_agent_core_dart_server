# Specify the Dart SDK base image version using dart
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Build minimal serving image from AOT-compiled `/server` and required system
FROM alpine:latest

RUN apk add --no-cache libc6-compat

WORKDIR /app

COPY --from=build /app/config/config.json /app/config/config.json
COPY --from=build /app/bin/server /app/server

# Start server.
EXPOSE 9527
ENTRYPOINT ["/app/server"]
