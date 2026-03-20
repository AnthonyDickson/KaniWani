# To Do

- Rename 'token' endpoints to 'session'
- Clear expired sessions on a schedule
  - Cannot be done on a request with a cookie referencing an expired session because the cookie will expire and not be
    sent.
- Move logic for protecting routes to a middleware layer and add exceptions for the login and registration endpoints
  - Static files will still be accessible so long as `wisp.serve_static` is before the auth middleware
- Look into using https://github.com/kanidm/kanidm and https://github.com/fweingartshofer/oauth for OAuth 2.0

## Nice to haves

- Add password strength meter corresponding to gzxcvbn score
