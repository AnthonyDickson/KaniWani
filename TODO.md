# TODO

- Implement basic lessons
- Refactor `Model` to a record with a `page` field and move page variants out into own record types
- Split definitions column into primary meaning and secondary meanings
- Add example sentences for each vocab (start with HSK 1)
- Change home page to dashboard and add link to lessons with lesson count preview
- Update lesson page to have routes that allow for continuing after reload
  - Links for each step in lessons info, quiz and lesson item
- Add table for keeping track of last time lesson queuing was run so that it is run every 24 hours even with server restarts
- Allow multiple senses per word
  - For words that have multiple readings, each corresponding to different meaning
  - Some words with multiple readings/meanings have been split into multiple rows, these will need to be merged back
- Serve vocab up as JSON asset and have lesson queue return IDs?
- Consider moving database queries from source code into SQL files. Load them all at server start and load them into a
  dict. Use an enum as the keys. Not sure how well this would work with parameterised queries as it puts the query far
  away from the code that's calling it. Maybe do something like [squirrel](https://hexdocs.pm/squirrel/index.html)
- Review restructuring project with liveview like architecture
  - https://curling.io/blog/live-admin-without-javascript
  - https://hexdocs.pm/lustre/lustre/server_component.html
- Implement basic reviews
- Add a GitHub action that builds the Docker image and makes a release
- Factor out common component styles

## Nice to haves

- Use [Levenshtein Distance](https://en.wikipedia.org/wiki/Levenshtein_distance) for more forgiving answer checking.
  Answers with a distance of less than one or two could show "not quite" or something and give the user another chance
  at submitting their answer.
  - If going for a recursive implementation, use [rememo_javascript](https://github.com/hunkyjimpjorps/rememo_javascript)
    for the frontend or [rememo_erlang](https://github.com/hunkyjimpjorps/rememo_erlang) for the backend.
  - Simpler alternative for checking equal length strings: [Hamming distance](https://en.wikipedia.org/wiki/Hamming_distance)
- Display toast or alert for errors on API calls, especially in 500 range
- Common phases lessons
- Grammar lessons
- Look into using https://github.com/kanidm/kanidm and https://github.com/fweingartshofer/oauth for OAuth 2.0
