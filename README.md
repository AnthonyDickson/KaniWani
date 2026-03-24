# KaniWani

[![test](https://github.com/AnthonyDickson/KaniWani/actions/workflows/test.yml/badge.svg)](https://github.com/AnthonyDickson/KaniWani/actions/workflows/test.yml)

WaniKani, but for Mandarin.

Disclaimer: This project is not affliated in any way with WaniKani or Tofugu LLC, but it is heavily inspired by WaniKani :)

## Getting Started

The application is distributed as a Docker image and Docker Compose is the recommended way of running the server.
The application is intended to be run on a home server behind a reverse proxy for HTTPS.

1. Copy [compose.yaml](./compose.yaml) to your computer and update it if needed.
1. Set up the application database by running (first time only):
   ```shell
   docker compose run --rm web sh /cli/entrypoint.sh init-db --sql-path sql/ --output-db-path /app/data/kaniwani.sqlite
   ```
1. Reset your password:
   ```shell
   docker compose run --rm web sh /cli/entrypoint.sh reset-password --db-path /app/data/kaniwani.sqlite
   ```
1. Start the server:
   ```shell
   docker compose up
   ```

## Development

The project is split into three sub-projects:

- [client](client/)
- [shared](shared/)
- [server](server/)

See the `README.md` in the above folders for more info.

### Test Database

Run:

```shell
cd cli && \
gleam run -- init-db --sql-path ../sql/ --output-db-path ../server/data/kaniwani.sqlite
gleam run -- reset-password --db-path ../server/data/kaniwani.sqlite
```

### Docker

You can build the Docker image with:

```shell
./scripts/build_image.sh
```

and then run the server with:

```shell
docker compose up
```

## Attribution

HSK vocabulary lists are from <https://github.com/glxxyz/hskhsk.com>
