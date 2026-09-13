# Character barks

Status: Implemented, verified, and reviewed. Shared understanding and dialogue copy confirmed in Q18; implementation subsequently requested through the implement skill.

## Intent

Give player characters brief, silent dialogue during Battles, expressing earnest fungal zealotry, dark comedy, and comradeship. Barks are purely expressive: combat continues, with no dialogue-driven pause, gameplay effect, or interaction.

The domain term **Bark** is defined in the root [glossary](../../CONTEXT.md). The [24 approved lines](lines.md) contain six lines per trigger, including the user's five samples.

## Speakers and triggers

### Battle start

- The Flag bearer alone delivers one opening line, with the header “Flag bearer”. It has no personal name.
- This is the actual Battle opening, not each Unit's start hook. Revival never repeats the opening.
- Opening lines bypass the random occurrence roll, subject to speed, visibility, and Battle-lifecycle rules below.

### Enemy kill

- A living player Unit may react to its own credited enemy kill, with an initial 20% chance when eligible.
- Enemy deaths without a living credited player killer receive no kill Bark. This includes environmental kills and attacks whose owner has already died.
- Friendly sacrifices never trigger a kill celebration, even if existing combat bookkeeping credits them as kills.

### Permanent friendly death

- A random surviving player Unit may mourn a permanent friendly death, with an initial 50% chance when eligible.
- Temporary Zombie deaths do not trigger mourning. Their eventual permanent death can.
- Personalized lines use the fallen Unit's full display name, including Generation: for example, “Fear not, we will avenge you, comrade Wilson II!”

### Victory

- A random surviving player Unit delivers a victory line, bypassing the random occurrence roll.
- Victory can interrupt an active Bark and uses a two-second line within the existing celebration. Do not extend the transition to the next screen.
- Defeat clears any Bark immediately and keeps the existing transition timing. There is no final-death reading delay.

Player Units include Children and Adults. Enemies never speak. The Flag bearer speaks only at Battle start. Reaction speakers must still be living and eligible when the bubble appears.

## Frequency and competing events

- At most one Bark bubble is visible at a time.
- Finish the current line; only victory can interrupt it with another line. Drop kill/death reactions while busy instead of queueing them.
- After a kill or mourning reaction, leave a three-second quiet gap before another reaction. These are initial tuning values, alongside the 20% kill and 50% mourning chances.
- When idle kill and mourning events coincide, mourning takes precedence. Resolve nested combat effects before selecting and validating the speaker.
- Opening and victory bypass chance rolls; victory also bypasses the reaction cooldown. At opening, let initial Battle effects settle before showing the line. If those effects already end the Battle, outcome handling takes precedence.
- Keep the existing named “has fallen” and kill-streak callouts. They remain reliable event feedback when no Bark plays.

## Bubble presentation

- Match the supplied [visual reference](bubble-reference.png): cream paper with irregular cut edges, dark lettering, and a teal header containing the speaker's name.
- Use each Unit's full display name in the header, including its Generation suffix. The reference's “Info” and trading text are sample artwork content, not dialogue copy.
- Position the bubble above the speaker, following their movement. Its tail points downward toward that character.
- The bubble scales with the battlefield, including camera zoom.
- Show the whole line at once. Normal lines last about three seconds; victory lines last two seconds. The in-run menu pauses the reading timer.
- Only show a bubble that fits above a visible, living speaker. If its speaker dies, leaves the screen, or the bubble can no longer fit, end it immediately. Do not pin offscreen dialogue to a screen edge.
- Wrap the authored lines and full names within the paper, with enough inset for the irregular edges. Keep the speaker and nearby combat feedback legible.

## Fast-forward and lifecycle

- Barks appear only at the player's selected 1× Battle speed.
- Selecting 2× or 4× removes the active bubble immediately and suppresses new Barks. Returning to 1× allows only fresh events; nothing missed is replayed.
- Starting a Battle at 2×/4× skips its opening Bark. A fast-forwarded victory also remains silent: the engine's normal end-of-Battle time-scale reset must not accidentally re-enable dialogue.
- The in-run menu freezes the active bubble's timer and reaction quiet gap. Resume continues them normally.
- Clear active dialogue and pending event candidates when the Battle ends or its scene exits. Victory's two-second line is the explicit outcome-specific exception before normal scene cleanup.

## Writing and repetition

- Use the shared voice and event-specific pools in [lines.md](lines.md), with the Flag bearer assigned only to the opening pool.
- Draw from each pool without repeating a line until that pool is exhausted across the Run, then reshuffle. Reset pool history on a new Run. Only lines actually shown consume pool entries.
- Avoid choosing the same Unit for consecutive mourning/victory lines when another eligible survivor exists.
- `{fallen_name}` is a placeholder for the deceased Unit's full display name, not the speaker's name and not a hard-coded Wilson.

## Implementation constraints

- Keep the change focused on dialogue presentation and event observation. Bark selection must not consume gameplay randomness or change combat outcomes, spawning, movement, damage, revival, or physics timing.
- Reuse the existing paper UI art and typography. The Scout bubble already uses cream paper and a teal heading. Its separate tip has a different curved edge treatment; the new downward tip should match the reference's flat paper style.
- Keep event handling aligned with the actual Battle lifecycle. Unit start hooks also run on revival, and initial hooks can cause immediate deaths.
- Preserve full character names before death cleanup. Revalidate speaker survival after nested death effects.
- No new settings control is required for this version; the confirmed display rule follows combat speed.

## Acceptance checks for implementation

The focused runtime scene exercises these behaviors. Commands and results are recorded in [verification.md](verification.md).

- At 1×, the Flag bearer gives one opening line; Children and Adults can deliver their applicable reactions. Enemies do not speak.
- A player killer can celebrate an enemy kill; friendly sacrifices, environmental kills, and dead killers do not produce kill Barks.
- Permanent death can trigger mourning with the correct full name. Temporary Zombie death and revival produce neither mourning nor a repeated opening.
- Simultaneous/nested deaths keep the one-bubble limit, honor mourning priority, and never select a dead speaker. Ordinary reactions do not interrupt or build a backlog.
- Normal lines last three seconds and victory lines two seconds. Menu pause freezes reading time and reaction cooldown. Victory interrupts when needed and does not delay the transition; defeat clears immediately.
- Changing from 1× to 2×/4× clears an active line. Starting fast or returning to 1× does not replay skipped openings/events. End-of-Battle time-scale reset does not reveal a Bark during a fast-forwarded Battle.
- Visual checks cover long Generation names, the longest mourning line, camera zoom and movement, crowded combat with existing callouts, screen edges, and a speaker dying mid-line. The teal name header and downward paper tail remain readable and correctly attached.
- Repeated Battles cycle each event's line pool across the Run and vary mourning/victory speakers when possible; a new Run resets history. Bark randomness leaves combat results unchanged.

## Decision record

Q1–Q17 settled scope, presentation, trigger rules, speaker selection, timing, fast-forward suppression, and repetition. Q18 confirmed this specification and the 24 dialogue lines. The subsequent implement request authorized implementation, review, and a commit on the current branch.

No ADR is needed: these are reversible feature and presentation choices without a costly architectural commitment.
