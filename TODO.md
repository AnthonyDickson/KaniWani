# To Do

- Set domain in auth token, use env to set to localhost for dev and a proper domain in the docker image
- Return 303 and redirect to login page on registration when a password has already been set
- Use https://hexdocs.pm/gzxcvbn/1.0.0/index.html for checking password strength
  - Can use on both frontend and backend. Use debounce on frontend?
- Automatic token refresh
  - Scheduled task on frontend or on every request to backend?
- Look into using https://github.com/kanidm/kanidm and https://github.com/fweingartshofer/oauth for OAuth 2.0
