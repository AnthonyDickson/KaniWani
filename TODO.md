# To Do

- Display toast or alert for errors on API calls, especially in 500 range
- Look into using https://github.com/kanidm/kanidm and https://github.com/fweingartshofer/oauth for OAuth 2.0

## Nice to haves

- Add password strength meter corresponding to gzxcvbn score
- Use [Levenshtein Distance](https://en.wikipedia.org/wiki/Levenshtein_distance) for more forgiving answer checking.
  Answers with a distance of less than one or two could show "not quite" or something and give the user another chance
  at submitting their answer.
  - If going for a recursive implementation, use [rememo_javascript](https://github.com/hunkyjimpjorps/rememo_javascript)
    for the frontend or [rememo_erlang](https://github.com/hunkyjimpjorps/rememo_erlang) for the backend.
  - Simpler alternative for checking equal length strings: [Hamming distance](https://en.wikipedia.org/wiki/Hamming_distance)
