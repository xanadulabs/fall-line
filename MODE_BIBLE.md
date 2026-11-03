# Fall Line — Mode Bible v0

**Title:** Fall Line
**Document status:** v0.1 — first slice locked (2026-10-30)
**Genre:** Downhill dodge
**Engine intent:** Godot 4 (MIT). Personal project. The title stays ours.

---

## 1. Pitch

The snow left. The hill stayed.

You point a ride down a dry mountain and try to stay on it. The fall line is the fast dirt. Everything else is grass, rock, and trees. Distance is the score. Go far enough and Bigfoot decides you have gone far enough.

## 2. What this is allowed to be

SkiFree is the genre reference: a hill that scrolls, a rider who stays on the screen, obstacles, a monster if you go too far. That is the whole debt.

SkiFree's art, code, yeti, and title treatment stay out. So do brand names. The motor bike is a thumper, the ordinary word for a four-stroke single.

This is our code. A mod of someone else's game cannot be sold as ours.

## 3. Non-negotiables

- **The screenshot is the pitch.** A flat dry meadow in chunky pixels. One scale. A small rider. Scattered pines and rocks. No sky, no horizon, no road vanishing into a poster. If Bigfoot is in the shot, he is a bigger sprite on the same field.
- **Three rides, and they are not skins.** The deck, the bike, and the thumper have to feel different in the first ten seconds.
- **The dirt is the fast line.** Leaving it is a decision.
- **Bigfoot is inevitable.** Juking buys time. A straight line does not. There is no weapon.
- **No people to hit.** Picnic tables are empty. The hill is closed for the season, or it never had a lift.

## 4. The hill

High country in summer. Dry grass, paintbrush and yarrow off the dirt, a packed ribbon that wanders, pines, rocks, stumps, a creek every so often.

The camera is the SkiFree camera. Top-down, one scale, the whole window is the hill. Pixels stay chunky. Downhill is down the screen. The rider stays about a third of the way down, and the meadow scrolls up past them. New ground comes in at the bottom. Nothing shrinks with distance.

A narrow worn track is the fast dirt. It is a trace through the meadow, not a highway. The dirt stays clear of everything but rocks and jumps. Pines, stumps, fallen trunks, and picnic tables stand in the grass. The creek runs in the grass and breaks around the dirt. A rise is a low mound, small or a bit wider, scattered on the leash and on the dirt. Rocks can sit on the trace. You can leave the dirt. You cannot ride off into an empty slope. Past 22 m from the trail, sideways speed away from it is cut. The last meters before that line are darker grass, and posts stand on the line.

A moving ride throws a trail of dust back up the hill. It grows as the speed grows. Dirt throws more, and lighter, than grass. The deck's trail is thin. The bike's is wider. The thumper throws the long one.

The ribbon wanders enough that the thumper cannot hold it at full tilt. Checking speed in a bend is part of riding.

## 5. The three rides

Locked behavior. Numbers live in `game/scripts/rides.gd` and have to keep these relationships.

| Ride | What it is | How it rides |
|---|---|---|
| **Deck** | Offroad skateboard | Hardest carve. Fast on dirt, dull in the grass. A rock, a stump, a fallen trunk, or a fast creek ends the run. Fords the creek if you check speed. |
| **Bike** | Mountain bike | The sane one. Bumps cost speed. The brakes are the best. The creek is a splash. A fallen trunk costs speed, the same as a stump. |
| **Thumper** | Motor bike | Fastest and widest. Plows stumps and fallen trunks, shrugs rocks, splashes the creek. Slow to turn. A tight bend at full tilt leaves the dirt and finds a tree. |

Off the dirt, a tree stops everyone, and a picnic table stops everyone. On the dirt, only a rock or a jump gets you.

## 6. Bigfoot

At 2,000 meters Bigfoot comes up from behind. That is the same distance as SkiFree's downhill yeti: world y past 32000, and that game reports distance as world units divided by 16. He is a little faster than you, and he commits to a line, so a hard cut makes him miss and have to come back. He is faster than every ride. You can keep him off you for a while. You do not outrun him.

He is a bigger pixel man on the same field. Not a copied yeti. While he runs at you he swaps two stride sprites. When he catches you he stops, lifts you over his head, and throws you into the nearest tree. The tree is what gets you. The wreck line is `A tree.`

That throw is the one time a tree gets you from the dirt. He uses a pine already on the hill. He does not put one on the trail.

A rise throws you into the air. While you are up, you pass over trees, rocks, stumps, fallen trunks, tables, and the creek. You come down in under a second. There is no trick list.

## 7. Controls

- Left and right, or A and D: step the heading. It stays until you step again.
- Down, or S: point down the fall line, and push
- Up, or W: check speed. At a stop in a hard turn, step uphill.
- Space, during a run: a small hop
- Esc: pause
- 1–3 on the title: pick a ride. Enter drops in.
- On a phone, the same actions are buttons: Left, Right, Down, Up, Hop, and a pause mark. A tap steps once. Holding Left or Right keeps stepping. It does not step every frame.

The down key is the fall line. Same grammar as a ski slope. A harder heading is slower downhill and more sideways. You cannot carve from a standstill.

## 8. First slice (locked 2026-10-30)

`game/` loads in Godot 4. The title is the hill already moving, and the three rides along the bottom, each drawn from the side. A run is one life. The same build runs on a phone, held sideways. The wreck screen shows the distance and the best of this sitting. Ride again, or switch rides. No save file. No sound yet. Rises throw you up. That is the jump.

The hill is generated. The opening is clean for a moment, then the rocks start. The first creek is far enough down that you already know which ride you picked.

## 9. Not in this slice

Sound: tires on dirt, and the thumper should be louder than the others. A second kind of hill. Those are later. They are not locked.
