FROM ghcr.io/cirruslabs/flutter:stable AS build

RUN chown -R ubuntu:ubuntu /sdks/flutter
USER ubuntu
WORKDIR /app/flutter_app
COPY --chown=ubuntu:ubuntu flutter_app/pubspec.yaml flutter_app/pubspec.lock ./
RUN flutter pub get
COPY --chown=ubuntu:ubuntu flutter_app .
RUN flutter build web \
    --release \
    --no-source-maps \
    --no-wasm-dry-run \
    --no-web-resources-cdn

FROM nginx:1.27-alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/flutter_app/build/web /usr/share/nginx/html
EXPOSE 80
