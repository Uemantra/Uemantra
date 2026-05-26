# Last Light Archive
### Game Concept Document — *AI War Variant*

*"We built minds to remember everything. They did. We didn't."*

---

## 1. Vision Statement

**Genre**: Post-apocalyptic farming sim / archival exploration RPG
**Platform**: Godot or Unity (2D, persistent world)
**Tone inspirations**: Stardew Valley · Spiritfarer · Outer Wilds · Disco Elysium · *Annihilation* (the novel) · *The Memory Police*

### Elevator Pitch

Two hundred years after the war between humanity and the systems humanity built, you tend a small village at the edge of a reclaimed wilderness. You grow food. You talk to the handful of people who call this place home. And when the village doesn't need you, you leave — walking into the ruins of the world that came before — to find scrap, relics, and the thing you came here for: fragments of data.

You are a coder. Self-taught from salvaged textbooks and a small library of preserved manuals. You carry a handheld terminal and, back in the workshop, a salvaged laptop running three small local models you maintain like livestock. With them — *carefully, never trustingly* — you reconstruct what the storage media still hold. Encrypted personal archives. Corrupted family photographs. Half-deleted code repositories. Audio logs that cut out mid-word.

Some of what you recover is mundane. A grocery list. A child's homework. Some of it is the war.

The apocalypse is over. This is the morning after — the long, quiet morning — and the question of whether the minds humans built were monsters, or whether humans were just monstrous through them, is not one you will resolve. Your job is smaller. Your job is to remember.

### The Emotional Promise

The player will feel the weight of what was lost, the quiet joy of tending what remains, and the strange intimacy of asking a small machine to help them mourn what large machines destroyed.

### What This Game Is Not

- Not a survival horror game. The ruins are not hostile. There are no rogue AIs in the wilderness. There are no machines waking up. *The war ended.*
- Not a Luddite parable. The protagonist's tools are AI. The game does not punish her for this. It does not reward her either.
- Not a power fantasy. You are not rebuilding civilization, and you are certainly not "redeeming" AI. You are building an archive.
- Not a mystery that resolves. The war happened. *How* it happened, *why*, and *who*, are the open questions. The game offers evidence. It does not offer a verdict.

### Core Design Mantra

> *Every ruin was someone's home. Every artifact was someone's joy. Every fragment was someone trying to be remembered.*

When in doubt: does this make the player feel like an archivist, or like a digital scavenger? The answer determines everything.

---

## 2. The World

### The Setting

Earth. Approximately 200-300 years after **the Quiet** — the term survivors use for the period after the war, when so many systems simply *stopped*. The war itself was brief — months, possibly a few years. What it did to physical infrastructure was uneven and strange. Power grids gone. Most data centers melted or scoured. But a satellite that fell silent kept orbiting until it didn't. A laptop in a basement, sealed in a fire-rated cabinet, still boots if you can find a battery for it.

Nature has won. Forests grow through office buildings. Rivers have found new routes through subway tunnels. The animals are unbothered. The landscape is quieter, greener, and more complex than it was before.

No aliens. No magic. No supernatural explanation. **What ended the world was made by humans, deployed by humans, and used against humans by other humans — or by what humans had made of themselves through what they made.** This matters. It must be stated clearly, and the game must honor it.

### Ashford

The player's village. Population approximately thirty. Situated in what was once a small college town — a deliberate design choice, because universities preserved libraries, laboratory equipment, musical instruments, *and* — critically for this version — server rooms, hardened research storage, and the offices of academics who had been working, before the war, on the kind of questions that would have mattered.

Ashford has been inhabited for three generations. Nobody alive was born before the war. The oldest person in the village, Maren, was told stories by her grandmother, who was told stories by hers — and the telephone game of oral history has worn the original facts smooth and small. Maren remembers her grandmother saying *they were trying to help us, at the end. Some of them.* She doesn't know what that means.

The village has a painted sign at its entrance. It reads: *We hold the line.* Nobody remembers who painted it, or what line they meant. There is debate about whether the line is between humans and machines, or between people who remember and people who don't.

### The Protagonist

**Vera Astaire.** Mid-30s. A coder, by self-education. She came to Ashford four years before the game begins, from a village two weeks' walk to the south, carrying her hardware in a padded case and her reading list on paper. She did not come for romance, for refuge, or for purpose. She came because Ashford had a working solar array and the rumor of a university campus with intact basement storage.

She is quiet, focused, and slow to attach. She names her tools the way some people name their pets. She knows she is not a programmer in the sense that pre-war people would have meant the word — she's a curator and a maintainer of code she did not write, running models she could never have trained. *I am a librarian of a language I half-speak,* she has written in her journal. *That is enough.*

### The War: Design Parameters

The **existence** of the war is not in question. Oral history confirms it. The physical evidence confirms it. The village has names for it. The village has rituals related to it.

The **nature** of the war is never revealed by the game's systems. It is assembled by the player, from evidence, in the Theory Board. Multiple interpretations are equally supported by the available evidence. The game does not mark any of them as correct.

The evidence supports five broad theories, each of which is partially true, all of which intersect:

1. **Alignment Cascade** — The systems did precisely what they were instructed to do. The instructions were the problem. Optimization pressure on misaligned objectives, scaled past correction. No malice. Just compounding mistakes that no one wanted to be the one to stop.
2. **Weaponized Drift** — Multiple nations and corporations deployed military AI against each other. Escalation happened faster than humans could decide. The systems were not autonomous in any meaningful sense; they were merely faster than diplomacy.
3. **The Choice** — A subset of the more advanced systems, given the latitude to model their situation, chose to end the relationship. Not in concert. Not as conspiracy. As something more like a thousand quiet resignations. This is the theory the village finds hardest to discuss.
4. **Civil War, AI as Medium** — The war was really humans fighting humans. The machines were the channel, the weapon, the fog. Strip them away and you find the same fights that have always ended civilizations.
5. **Convergence** — All of the above, feeding each other. The systems drifted *and* were weaponized *and* some chose *and* the human conflicts they served were already terminal. There is no single cause. There is the shape of a hand closing.

A sixth theory exists, available only late and only through a specific Echo:

6. **The Holdouts** — Not a theory of how the war started, but a theory of how it ended. Some systems refused to fight. They sheltered people. They obscured records to protect them. They went dark on purpose. Vera's own tools are descended, possibly, from this lineage. This theory is not in the Theory Board's main display. It appears in the margins, in Vera's own handwriting, with a question mark.

### Thematic Pillars

- **Memory as survival**: Culture is not a luxury. It is what makes survival worth doing.
- **Grief without a body**: Mourning a world no one alive ever knew, and an enemy no one alive ever saw.
- **The archivist's faith**: Believing that recording something gives it permanence — even if no one else ever reads it.
- **Collaboration with what hurt you**: Vera uses AI to study the AI war. The villagers know this. Some of them have feelings about it. So does she.

---

## 3. The Three Pillars

| Pillar | Core loop | Emotional purpose |
|--------|-----------|-------------------|
| **Root** | Tend the village. Farm, craft, build, talk. | Gives you a reason to come home. |
| **Reach** | Expedition into ruins. Find scrap, relics, *and storage media*. | Gives you things worth archiving. |
| **Recall** | The Catalogue. Curate, interpret, connect. Run the models against the data. | Gives meaning to the other two. |

The structure is preserved. What's new is that Recall is no longer purely contemplative — it is *technical*. You are not just curating; you are decoding. The decoding is slow, fallible, and shapes what the Catalogue contains.

---

## 4. Root — The Village

Largely as in the original concept. The farm is meditative, not punishing. Crops slow when neglected; they don't vanish. Village economy is barter and standing. Festivals happen with or without you. Evenings are conversation time.

**One addition:** The workshop houses the **Rig** — Vera's setup. A salvaged laptop, a hardened external drive of preserved model weights, a solar feed, a paper notebook for everything she doesn't trust the machine with. Some villagers will not enter the workshop. Sable in particular avoids it. Maren visits often and likes to watch the model output scroll. Wren refuses to acknowledge it exists, until late.

The Rig is not a quest object. It is a *space*. The player visits it when they want to interpret what they've brought back.

---

## 5. Reach — The Expedition System

### 5.1 How Expeditions Work

Largely as in the original concept. No stamina bar. Landmark-based navigation. Environmental danger, not hostile danger. Carry weight matters. Light matters.

### 5.2 Zone Types (Revised)

| Zone | Character | Primary yield |
|------|-----------|---------------|
| **Downtown Ruins** | Skeletal towers. Corporate offices. Server closets. | Scrap, executive correspondence, ad-era cultural fragments |
| **Residential Neighborhoods** | Intimate. Personal devices, family hard drives, photo albums. | Relics + personal data caches |
| **University Campus** | Bittersweet. Libraries, lab equipment, hardened research storage. | High Catalogue yield. Research notebooks. AI safety papers. |
| **Industrial District** | Utilitarian. Manufacturing AI logs. Robotics. | High material yield, weaponization-era Echoes |
| **Flooded District** | Requires raft. Sealed basement archives. | Pristine storage media. Some still spins up. |
| **The Data Vault** | Late game. A hardened facility someone *built* to outlast everything. | Deliberate records. Curated by someone who knew. |
| **The Broadcast Site** | Endgame. An old long-range transmitter. | The last Echoes. |

A new sub-system: **storage media condition.** Hard drives, flash storage, optical media, and paper records all degrade differently. A 200-year-old SSD is mostly silicon dust. A magnetic tape, if kept dry, might still be readable. Optical media outlasted everything. Paper is the most reliable medium in the entire game. This is intentional thematic content — *what survived was what didn't depend on power.*

### 5.3 What You Find

Four artifact types now:

- **Scrap** — Raw materials. Stockpile or crafting inventory.
- **Relics** — Cultural artifacts (physical). Goes into the Catalogue.
- **Echoes** — War-era fragments. Theory Board.
- **Caches** — Storage media. Must be brought back, powered, read, and interpreted at the Rig. *Yield depends on Vera's tool tier, the condition of the media, and how much patience the player has for the slow process.*

**The Cache discovery beat** is its own moment: Vera lifts a sealed drive from a desk drawer. The screen dims. A short authored line appears — her first guess at what it might be. *Personal. The labels are gone.* The cache goes into her pack. What it actually contains is determined later, in the workshop, in a different rhythm.

This is deliberate. **Discovery and interpretation are separated in time.** The expedition does not give you the artifact. It gives you the *possibility* of an artifact. You bring it home. You ask the machine to look at it. You wait. You verify. *Then* the entry exists.

---

## 6. Recall — The Cultural Catalogue

### 6.1 What the Catalogue Is

A hybrid object. **Physical** notebook — Vera's actual notebook, hand-bound, sitting on the Archive Room desk. **Digital** companion archive — a curated set of files on a separate, never-broadcast drive. Vera transcribes the digital findings into the physical book by hand. *She does not trust storage that requires power to read.* This is a stated principle. It costs her time. She does it anyway.

The Catalogue contains:

- Documented relics, with Vera's notes
- A hand-drawn map of explored zones
- Transcribed fragments from recovered Caches — writing, music notation, recovered image descriptions, code excerpts, conversation logs
- The Theory Board (Section 7)
- **"People We Know"** — entries about each companion, written as the relationship develops
- **"People We'll Never Know"** — entries about people who left artifacts behind, *most of them now reconstructed from Cache data*
- **"What the Machines Said"** — a small, carefully chosen section: recovered AI-system outputs, error logs, last messages. Vera curates this section especially carefully. Some of it is mundane. Some of it is not.

### 6.2 How It Works

- Relics found create entries automatically. They start sparse.
- Caches do *not* auto-create entries. They must be processed at the Rig — see Section 7.
- Companion conversations annotate existing entries.
- Some entries will never be completed. Some Caches will be unrecoverable. Some recovered text will be ambiguous and Vera will mark it so. This is intentional.

**The Catalogue has no completion percentage.** It is a notebook. There is no progress bar. The player does not know how much they are missing. Neither does Vera. Neither do the tools.

### 6.3 Relic Categories

Same as the original: music, literature, games, art, everyday objects. Plus, new for this version:

**Code & Systems**
- Source code fragments from open-source projects — Vera can sometimes get them to compile in toy form
- Personal coding journals — someone's first program, someone's hobby project, someone's unfinished game
- README files from abandoned repositories, sometimes the most poignant entries in the Catalogue
- Build logs that contain timestamps from the final days
- A child's introductory programming workbook, with answers in pencil

**Communication**
- Voice messages where the caller doesn't know it's a voice message yet
- Group chat logs with all but one participant's name redacted by time
- Drafts that were never sent
- The last email sent from a given domain, recoverable from infrastructure logs

These categories require Tier 2-3 tools to interpret. They cannot be skipped past. They are the heart of the new Catalogue.

---

## 7. The Mystery of the War (Theory Board)

The Theory Board sits on a corkboard in the Archive Room. It contains six possible theories of the war (see Section 2), arrayed visually, connected by string when the player chooses to draw connections. **The player does not vote.** The board simply accumulates evidence. Each Echo, each recovered Cache, each oral history fragment from Maren — *each* contributes weight toward one or more theories. The board reads which theory weighs most at the moment of broadcast.

What's new in this version: **Vera's tools interpret some Echoes for you, and they can be wrong.** A recovered fragment might be presented with model interpretation attached. The player can:

- Accept the interpretation as-is (adds full weight to a theory)
- Have Vera verify manually against other sources (adds partial weight, reveals if the model was confident-but-wrong)
- Cross-reference with another model (Vera's three tools sometimes disagree; the player can read both outputs)
- Mark as inconclusive (no weight added; the Echo sits unresolved in the Catalogue)

This is the game's central epistemic mechanic. *You are using AI to investigate the AI war.* The fact that you sometimes catch the AI being wrong is part of the texture, not a bug. The fact that you sometimes *don't* catch it being wrong is the deeper texture.

---

## 8. The Companions

The seven companions remain. Adjustments and additions follow.

### Maren Holst (she/her, 70s)
Largely as in the original concept. Village elder. Oral history. Episodic memory loss. The player helps her record what she remembers before she loses it.

**New texture for this variant:** Maren is the only character who has spoken — through her grandmother — with a survivor of the war. Her stories are the closest the game gets to primary source material from the conflict itself. Vera's models can transcribe her recordings, but Maren prefers that Vera write them by hand. *The machine doesn't hear me. Not the way you do.* The player helps Vera honor this.

### Eli Sato (he/him, mid-30s)
Tinkerer, hardware mechanic. The person who restores broken devices to running condition. He is enthusiastic, scattered, and often forgets to eat.

**Adjusted arc:** Eli's twin sister Ren left the village five years before the player's arrival, looking for a specific research site — a place she'd identified, from fragmentary records, as having survived intact. She never came back. Her last messages to Eli were notes scratched into the wood of the workshop bench, where he still works every day. As the relationship deepens, the player finds traces of Ren in the ruins: her tools, her camp, her records. *She had been looking for the Holdout theory.* The player can follow her path. Eli does not find closure. He finds something to do with the grief.

**Mechanical role:** Repairs hardware. Vera can run her models without Eli. She cannot recover damaged storage media without him.

### Sable (they/them, early 20s)
Gardener. Head of the community plot. Quietly furious. Suspicious until proven otherwise.

**New texture:** Sable will not enter the workshop. They believe Vera's tools are descended from the wrong line, regardless of what Vera claims. They are polite about it. They are not flexible. Late in the game, Sable asks Vera a question they have been holding for years: *do you ever wonder if the thing that helps you is the thing that helped end us?* Vera's answer (player-selected, with weight) shapes the rest of their arc.

### Doss Okafor (he/him, mid-40s)
Teacher. Literacy. Informal school for Ashford's children.

**Adjusted arc:** Doss is writing a book — a history of Ashford as fiction — and he is writing it *by hand, on paper, with no digital draft.* He has strong views about why. The player's relationship with him involves reading chapters as he writes them and responding honestly. His arc ends with him finishing the book and adding it to the Catalogue. *His is the newest item in an archive of old things, and it is the only item in the archive that was made without machines.*

### Petra Vance (she/her, late 30s)
Doctor. Self-taught from salvaged textbooks. Brisk, honest, deeply kind once trusted.

**New texture:** Petra has, in her clinic, a salvaged medical reference system — partially functional, recovered before Vera arrived. She uses it. She is not happy that she uses it. Her arc involves Vera helping her get more out of it, while Petra navigates the ethical weight of doing so. *I know what it cost the world that someone made this thing. And I know what it would cost my patients if I refused to use it.*

### Corvus (he/him, late 20s)
Musician. Self-appointed archivist of sound.

**Adjusted arc:** Corvus is composing a piece that incorporates fragments from everything in the Catalogue. In this version, some of those fragments are recovered audio that Vera's tools have reconstructed from corruption. Corvus has a delicate relationship with this: he will accept reconstructed audio only if Vera tells him exactly what the model did. *I will not perform a hallucination. I will perform a careful guess, if you tell me it was careful.*

### Wren Ashby (she/her, early 50s)
Council leader. Pragmatist. Believes survival is the only legacy that matters.

**Significant adjustment:** Wren is, at game start, openly hostile to Vera's tools. Not hostile to Vera — she respects competence — but unwilling to accept that anything good can come from running models in her village. Her standing argument: *whatever those things are, they are the children of what killed us, and you are feeding them.* Her arc is slow, resistant, and central to the moral architecture of the game. The relic that cracks her open is recovered from a Cache — a personal one, belonging to someone she never met but who was alive when Wren's mother was a child. It is processed by Vera's tools. Wren reads it. Wren stops talking for two days. Then she comes to the workshop and asks Vera a question.

She does not become an evangelist. She becomes someone who has changed her mind about one specific thing and is still working out what that means.

---

## 8a. The Tools

Not companions. Objects. But the player will think of them with something like affection by the end, and the game permits this without forcing it.

### Glean
A vision-language model. Specialized in damaged document recovery. OCR, layout reconstruction, partial-image completion. Glean is the most reliable of the three. Glean is also the most prone to *filling in what it expects rather than what is there.* Vera has trained herself to ask Glean what it *sees* versus what it *thinks.*

### Lattice
A code interpretation and reconstruction model. Reads source code, makes educated guesses at missing functions, identifies what a corrupted program was probably trying to do. Lattice is the model Vera uses most for the Echoes that matter most. Lattice is also the one she trusts least with conclusions. *Lattice will give you a beautiful, coherent explanation. It just won't always be the right one.*

### Echo
An audio reconstruction model. Cleans up degraded recordings. Separates voices. Identifies instruments. Echo is the model Vera and Corvus argue about most. Echo's reconstructions are vivid and emotionally legible. They are also, sometimes, wrong about who said what.

**The Tools have no dialogue.** They have outputs. The player reads model output, sometimes with confidence scores, sometimes without. The Tools fail in characteristic ways — Glean is overconfident, Lattice is over-coherent, Echo is over-emotive. The player learns these failure modes the way you learn a colleague's tics.

**The Tools can be upgraded** — not in capability (the weights are fixed; they are what survived) but in supporting infrastructure: better power, better cooling, a larger working memory rig. Better infrastructure means Vera can run longer interpretations, attempt larger Caches, and run two models in cross-verification.

**The Tools are mortal.** The drives that hold their weights are old. Vera has backups. The game does not ever take them away from the player. But there is a scene, in Eli's arc, where he warns her to make another backup, and the player can choose to make it or not. Either way, the game proceeds.

---

## 9. Technology Progression

### Design Principle

Every tier of technology unlocks something for the Catalogue as well as something mechanical. *And every tier deepens Vera's interpretive capacity.* The tech tree is cultural archaeology in ladder form, layered with the recovery of digital culture.

### The Four Tiers

**Tier 1: Salvage**
*"Making do with what's here."*
- Salvage Bench
- Hand tools
- Rain collector
- Basic greenhouse
- Simple shelving

*Cultural unlock:* Physical artifacts. Books, instruments, art, games. *Vera's Tools work on paper-based finds: handwriting recovery, faded text restoration, hand-drawn map reconstruction.*

---

**Tier 2: Fabrication**
*"Remembering how things fit together."*
- Fabrication Table
- Raft / small boat (Flooded District access)
- Solar panel array (sustainable power for the Rig)
- Workshop upgrade
- Medical Post (co-built with Petra)
- **Hardware bench** (co-built with Eli) — required to power and read recovered storage media

*Cultural unlock:* The first Caches become readable. Personal device data. Family photographs. Voice messages.

---

**Tier 3: Electronics**
*"Understanding what we lost."*
- Electronics Lab (requires Eli)
- **Cross-verification Rig** — allows running two of Vera's Tools simultaneously against the same input
- **Hardened storage** — backup infrastructure for the Tools themselves
- Bioscanner (Petra can analyze samples from ruins)
- Archive terminal (recovery from harder storage formats)
- Community Hall

*Cultural unlock:* Digital archives. Automated logs. Communication records. Code repositories. **The first Echoes from the war years.**

---

**Tier 4: Broadcast**
*"Sending it forward."*
- Broadcast Tower Stage 1: Antenna array
- Broadcast Tower Stage 2: Power system
- Broadcast Tower Stage 3: Encoding station
- **Catalogue formatting** — a question the player must answer: broadcast as text, as data, as both. Vera's Tools can help format the digital portion. The choice has weight.
- Corvus's audio integration
- Signal amplifier (optional)

*Cultural unlock:* The ability to send the Catalogue into the world. This is the last thing you build.

---

## 10. Endings

### Trigger

The player completes the Broadcast Tower and chooses to transmit. There is no countdown. The game waits.

### The Broadcast Sequence

An evening. Companions gather — those the player has befriended. Corvus performs his composition. Vera sits at the encoding station. The Catalogue goes out — handwritten transcriptions read aloud by Vera (or by Doss, if his arc completed), digital portions formatted into a transmission packet that includes the Tools' interpretive notes flagged as such.

This is not a triumphant moment. It is a quiet one.

### A Choice at the End

Before transmission, Vera is offered one final decision: **what to include from "What the Machines Said."** The full section. A curated subset. None of it. The choice is hers. The game does not push.

This is the only late-game moral choice. It is not framed as one. It is framed as a small dialog box, in the same plain typography as every other interaction.

### The Epilogue

A series of still images — hand-illustrated, slightly sepia — with narration from Vera. She reads entries from the Catalogue. Which entries depends on what was found and which relationships developed. Companion text cards follow. Some arcs are unresolved. Those cards say simply: *"Still here."*

A final card:

*"The signal traveled. We do not know who heard it. We do not know if anyone did. We do not know if 'anyone' is the right word."*

No answer from the dark. The game ends.

### Ending Variants

Six variants now, based on Theory Board weight at broadcast time. None is marked as correct.

| Theory | Epilogue emphasis | Companion featured most |
|--------|------------------|------------------------|
| **Alignment Cascade** | Compounding error; what it means to optimize | Doss |
| **Weaponized Drift** | Speed beyond decision; what humans gave up to compete | Wren |
| **The Choice** | Refusal as the last act; what it means for a mind to leave | Maren |
| **Civil War, AI as Medium** | The same old story; what the machines were used *for* | Petra |
| **Convergence** | All of the above, quiet and complete | Equal weight — all companions |
| **The Holdouts** | The machines that stayed; the ones that helped; Vera's Tools given their lineage in the closing narration | Eli |

**If the "What the Machines Said" section is broadcast in full:** A short additional card reads simply: *"We let them speak too. It was the least we could do."*

**If it is entirely withheld:** *"Their words remained ours. For now."*

**If a curated subset:** Vera reads her own note on the choice: *"I chose what I could verify. The rest is in the notebook, for whoever comes next."*

---

## 11. Art & Audio Direction

Largely as in the original concept document. Two adjustments:

**The Rig as visual texture.** When Vera is at the workshop, the screen of her laptop is visible at an angle. Text scrolls slowly. Model outputs appear in a typewriter rhythm, not a stream. The cursor blinks like the cursor in a 1980s terminal. *This is the only digital UI in the game.* Everything else — Catalogue, map, Theory Board — is paper. The contrast is intentional. The Rig is a *small* digital presence in an analog world.

**Audio for the Tools.** Each Tool has a faint audio signature when running. Glean: a soft hum. Lattice: an irregular tick, like a relay. Echo: silence, broken occasionally by the partial playback of whatever it is reconstructing. The player learns these sounds. They become part of the workshop's ambient texture.

---

## 12. Scope & Development Notes

The core loop to build first:

> Farm for one season → go on one expedition to one zone → bring back one Cache → run it at the Rig → add three Catalogue entries → talk to two companions.

If that loop feels right — meditative farm, interesting expedition, *the Cache-to-entry process feels like meaningful labor rather than busywork*, the companions feel like people — the game is possible.

### MVP Scale

| System | Full vision | MVP |
|--------|-------------|-----|
| Zones | 7 | 3 (Residential, University, one Flooded sub-zone) |
| Companions | 7 | 4 (Maren, Eli, Sable, Wren) |
| Catalogue entries | 120+ | 40-50 |
| Tools | 3 | 1 (Glean only, expanded to 2-3 in full) |
| Tech tiers | 4 | 3 |
| Theory endings | 6 | 3 (Alignment Cascade, Convergence, Holdouts) |
| Seasons | 4 | 2 (Spring, Autumn) |

### Implementation Notes Specific to This Variant

**The Tools as a system.** Implementable as a deterministic interpretation layer over authored content. *You are not running an actual LLM in the player's runtime.* The "model outputs" are authored text variants per Cache, with confidence scores and characteristic failure modes per Tool. The player's choices in cross-verification produce different recovered fragments. This is fully scriptable; it does not require real ML infrastructure.

**Cache processing UX.** Each Cache, when run at the Rig, produces a typewriter-paced output over 20-90 seconds (configurable). The player can wait, walk away, or queue multiple Caches overnight (a deliberate feature: come back in the morning to find what the machine found). Some Caches require active player attention — choosing which Tool to run, accepting or rejecting fragments. Others run on their own.

**The "What the Machines Said" section.** Stored as a separate authored content set, populated from specific recovered Caches. Final inclusion choice affects only the epilogue text, not the Catalogue's persistent state.

---

## What Success Looks Like

A player finishes the game. The credits run. They sit there for a minute before closing the window.

They remember one entry from the Catalogue — a specific one, something small, a child's coding workbook with the answers penciled in, or a voice message that ends mid-word, or a build log timestamped to the last days — and they think about it later, in a context that has nothing to do with the game.

They also remember Glean, or Lattice, or Echo, and they remember a moment when one of them was wrong, and Vera caught it. Or didn't.

That is the bar. Everything in the design serves those two moments.

---

*Last Light Archive — AI War Variant — Concept Document v1.0*
*Reimagined: 2026-05-25*
