# To Do

- Return 404 when logging in but a password has not been set yet, and display an error message that points the user to
  the registration page
- Use https://hexdocs.pm/gzxcvbn/1.0.0/index.html for checking password strength
  - Can use on both frontend and backend. Use debounce on frontend?
- Automatic token refresh
  - Scheduled task on frontend or on every request to backend?
- Look into using https://github.com/kanidm/kanidm and https://github.com/fweingartshofer/oauth for OAuth 2.0
