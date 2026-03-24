# KaniWani

[![test](https://github.com/AnthonyDickson/KaniWani/actions/workflows/test.yml/badge.svg)](https://github.com/AnthonyDickson/KaniWani/actions/workflows/test.yml)

WaniKani, but for Mandarin.

Disclaimer: This project is not affliated in any way with WaniKani or Tofugu LLC, but it is heavily inspired by WaniKani :)

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

## Attribution

HSK vocabulary lists are from <https://github.com/glxxyz/hskhsk.com>
