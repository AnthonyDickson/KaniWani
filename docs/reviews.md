# Reviews

## Purpose

To help users memorise hanzi and words learned in [[lessons]]] via a WaniKani-like SRS [1]

## Definitons

**SRS** means spaced repitition system [2]
The **reading** of a hanzi or word is its corresponding pinyin and tone
The **meaning** of a hanzi or word is its corresponding English dictionary definition

## Requirements

- All items unlocked via [[lessons]] should be added to a review pool
- Each item in the review pool should have one of the following SRS stages associated with it:
  1. Apprentice 1
  1. Apprentice 2
  1. Apprentice 3
  1. Apprentice 4
  1. Guru 1
  1. Guru 2
  1. Master
  1. Enlightened
  1. Burned
- When an item is assigned an SRS stage, it should not show up in the users review queue until the correponding interval
  has passed:
  | SRS Stage    | Time until next review |
  | :----------- | ---------------------: |
  | Apprentice 1 |                4 hours |
  | Apprentice 2 |                8 hours |
  | Apprentice 3 |       1 day (24 hours) |
  | Apprentice 4 |       2 day (48 hours) |
  | Guru 1       |     1 week (168 hours) |
  | Guru 2       |    2 weeks (336 hours) |
  | Master       |    1 Month (672 hours) |
  | Enlightened  |  4 Months (2688 hours) |
  | Burned       |                    N/A |

  The time to add the review into the queue should be rounded down to the beginning of the hour
- The reviews page should quiz the user on items that are ready for review
- The reading and meaning of an item should be quizzed separately
- Items should be quizzed in a random order
- When both the reading and meaning of an item have been answered the item should be updated:
  - If answered correctly, increment its correct answer count and advance it to the next SRS stage
  - If answered incorrectly, increment its incorrect answer count and calculate its new SRS stage with:
    `new_srs_stage = current_srs_stage - (incorrect_adjustment_count * srs_penalty_factor)`
    where `incorrect_adjustment_count` is the number of incorrect times you have answered divided by two and rounded
    up. `srs_penalty_factor` is 2 if the `current_srs_stage` is at or above 5, otherwise it is 1 [1].
    An item cannot go below stage 1 "Apprentice 1"
- Once an item reaches the stage "Burned", it is moved from the review pool to the burned list

## References

1. WaniKani, _WaniKani's SRS Stages_. URL: <https://knowledge.wanikani.com/wanikani/srs-stages/>, accessed 2026-03-23
1. Wikipedia, _Spaced repetition_, Jan 2026. URL: <https://en.wikipedia.org/wiki/Spaced_repetition>, accessed 2026-03-23
