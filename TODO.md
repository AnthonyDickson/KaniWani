# To Do

- Move logic for protecting routes to a middleware layer and add exceptions for the login and registration endpoints
  - Static files will still be accessible so long as `wisp.serve_static` is before the auth middleware
- Add an error page if checking auth fails with status code in 500 range
- Display toast or alert for errors on API calls, especially in 500 range
- Look into using https://github.com/kanidm/kanidm and https://github.com/fweingartshofer/oauth for OAuth 2.0

## Nice to haves

- Add password strength meter corresponding to gzxcvbn score
