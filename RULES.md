# Block Drop — Rules

This document is the authoritative source of truth for Block Drop gameplay.
If the implementation conflicts with this document, fix the implementation.

## 1. Objective
Guide falling tetromino blocks into a 10×20 well. Fill complete horizontal
rows to clear them and score points. Survive as long as possible — the game
ends when the stack reaches the top of the well.

## 2. Setup
- The well is 10 columns × 20 visible rows.
- Pieces spawn above the well and fall from the top center (column 3).
- Pieces are drawn from a 7-bag randomizer: each bag contains one of each of
  the 7 tetrominoes (I, O, T, S, Z, J, L) in random order; a new bag starts
  when the current one is empty. This guarantees no long droughts.
- The player sees the next 3 pieces in the NEXT tray.
- One piece may be stored in the HOLD tray.

## 3. Turn order
Play is continuous (real-time), not turn-based. The engine cycles through
phases: spawning → falling → locking → clearing → spawning … until game over.

## 4. Legal moves
While a piece is falling (or during its lock delay):
- Move left / right by one column (wall-kick nudges of up to ±2 columns are
  applied automatically when rotating near walls or the stack).
- Rotate 90° clockwise.
- Soft drop: move down one row (+1 point per row).
- Hard drop: instantly place the piece at its ghost position (+2 points per
  row traveled).
- Hold: swap the active piece with the held piece (once per spawned piece;
  the swap is refused with an "invalid" sound if already used).

## 5. Illegal moves
- Any move/rotation that would place a block outside the well or overlapping
  a locked block is refused (with an "invalid" feedback sound).
- Hold cannot be used twice for the same spawned piece.
- No input is accepted while lines are clearing, while paused, or after
  game over.

## 6. Captures
Not applicable — there are no captures in Block Drop.

## 7. Special rules
- **Ghost piece:** a pale outline always shows where the active piece would
  land if hard-dropped.
- **Lock delay:** when a piece first touches the stack/ground it does not
  lock instantly — a 500 ms delay starts. Successful moves/rotations during
  the delay reset it (max 15 resets), then the piece locks.
- **Hold refresh:** the hold slot becomes usable again every time a new
  piece spawns.
- **Blitz mode:** a 120-second countdown runs; the game ends when time
  expires regardless of stack height.

## 8. Scoring
- Soft drop: +1 per row. Hard drop: +2 per row traveled.
- Line clears (multiplied by current level):
  - Single: 100 × level
  - Double: 300 × level
  - Triple: 500 × level
  - Tetris (4 lines): 800 × level
- Combo: consecutive piece-locks that each clear lines build a combo;
  each chained clear adds +50 × combo × level.
- A lock that clears no lines resets the combo.

## 9. Winning conditions
Block Drop is a score-attack survival game — there is no final "win".
Victory is a new personal best score. In Blitz mode, the run simply ends
when the timer expires and the score stands.

## 10. Draw conditions
Not applicable.

## 11. AI strategy
Not applicable — Block Drop is single-player with no opponents.

## 12. Edge cases
- A piece that locks with any block above the visible field ends the game
  ("block out"), even if the spawn area looked clear.
- If a newly spawned piece immediately collides with the stack, the game
  ends ("top out").
- Clearing lines never creates floating blocks: rows above collapse down
  by exactly the number of cleared rows, preserving column order.
- Pausing freezes gravity, lock delay, line-flash and the Blitz clock;
  resuming re-arms each timer from the current phase.
- App backgrounding pauses the game the same as the pause button.

## 13. Test cases
1. Move a piece against the left wall — it stops at column 0, no crash.
2. Rotate a piece against the right wall — wall kick shifts it left, or the
   rotation is refused with feedback.
3. Hard drop an I-piece into a 4-line well setup — "TETRIS!" toast, +800 ×
   level, all 4 rows clear and rows above collapse.
4. Fill the well to the top — game over overlay appears exactly once with
   the final score; PLAY AGAIN restarts cleanly.
5. Pause mid-fall, background the app, return — piece resumes falling;
   no double gravity (speed unchanged).
6. Use HOLD twice on one piece — second attempt refused with feedback.
7. Clear 10 lines in Classic — "LEVEL 2" toast, drop interval shortens.
8. Blitz: let the 120 s timer expire — "Time's Up!" overlay with score.
9. Kill the gravity timer (simulated) — the watchdog restarts falling
   within 2 s; the game never freezes.
10. Rotate during lock delay 16 times — the piece locks on the 16th nudge
    attempt (lock-delay reset cap enforced).
