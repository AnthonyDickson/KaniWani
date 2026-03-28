# KaniWani

[![test](https://github.com/AnthonyDickson/KaniWani/actions/workflows/test.yml/badge.svg)](https://github.com/AnthonyDickson/KaniWani/actions/workflows/test.yml)

WaniKani, but for Mandarin.

Disclaimer: This project is not affliated in any way with WaniKani or Tofugu LLC, but it is heavily inspired by WaniKani :)


## Getting Started

KaniWani is setup as a single user web app.
It is intended to be put behind a reverse proxy.
It also requires an external OpenID Connect (OAuth2) server for authentication.

## Development

The project is split into three sub-projects:

- [client](client/)
- [shared](shared/)
- [server](server/)

See the `README.md` in the above folders for more info.

### Docker

You can build the Docker image with:

```shell
./build_image.sh
```

and then run the server with:

```shell
docker compose up
```
