# server

This is the backend server for KaniWani.
To view the web app, first [build the client](../client/README.md#Development) and then [start the server](#development).

## Development

```shell
gleam run   # Start the server
```

Run the server and restart on file changes:

```shell
watchexec --restart -w src/ -w priv/ -- gleam run
```
