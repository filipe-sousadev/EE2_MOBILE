# Eras de Conquista — rules sheet

**Where the numbers come from.** The person asked for "Empire Earth II on a Samsung A56".
The target folder (`/home/ar1m4/Downloads/EE2/`) contains only a 520 KB UPX-packed GOG Galaxy
downloader (evidence `ev_11f4396b…`) and a Lutris install script (evidence `ev_099c9e7d…`).
The game itself (EE2.exe, `zips/db.zip` with its unit tables, art, sounds) is not there, so no
code could be decompiled and no data file read (finding `fnd_1`, open unknown `unk_0583f22d0a01008f`).
This is also an **original** game in the same genre (epoch-based real-time strategy), not a copy of
that game: its own name, units, art and numbers. **Every value below is estimated** (genre-typical
and balanced in long simulated matches with `--soak`); the same values live in `scripts/data.gd`
and `mechanics.json`.

## Decompilation of the original's program (Deep mode)
The only program in the target folder is `GOG_Galaxy_Empire_Earth_2_Gold_Edition.exe` (sha256 8de8228d…).
- Packed with UPX: the file has 3 functions. `entry` @ 0x501620 is the UPX decompression stub, which tail-calls the
  original entry 0x435126. `sub_435126` and `sub_4a6000` lie in the empty packed section (evidence `ev_a271623d…`, `ev_3555cd6e…`).
- Unpacked copy (`checks/unpacked/installer_unpacked.exe`, sha256 c9eb405f…): 2276 functions, 8931 strings (`ev_5beb8115…`).
  Its version info calls it "GOG Galaxy - Game Installer.exe" (`ev_f6bf8105…`).
- Main routine `FUN_0041efe5` @ 0x41efe5 (Ghidra, `ev_8aee1fad…`): sets the log path
  `C:/ProgramData/GOG.com/Galaxy/logs/InstallerBootstrapper.log`, the product id "1207658844" and the title, checks
  whether GOG Galaxy is installed through the registry (`sub_4084f0` @ 0x4084f0, `sub_408251` @ 0x408251), extracts the
  embedded .NET "GalaxyWebInstaller" (`sub_416105` @ 0x416105, `sub_41fdef` @ 0x41fdef), copies it and starts it with
  `CreateProcessW`. Error messages come from `sub_414d7f`/`sub_414f62` ("GOG Galaxy Web Installer failed to initialize…").
- String searches for damage, health, hit points, attack, armour, epoch, villager, citizen, food, wood, stone, gold and
  unit (`ev_2a1b0b86…`, `ev_cf747c81…`) find only Windows/.NET resource-manager names and the installer's download-speed
  fields (`speedBs`, `speedKbs`, `speedMbs`). Its web addresses are all support.gog.com and GOG registry keys (`ev_490d5856…`).

**Result:** the program is a downloader for the game, not the game. It contains no movement, combat, economy, epoch or
AI code, so no value below could be taken from it (finding `fnd_2`). The game's own `EE2.exe` and `zips/db.zip`
(named in the Lutris script) are not on this computer. The numbers therefore stay estimated. They can be replaced
with real ones if the installed game folder is given to Craft Anything.

## Scale
- Map 3840 × 2560 px, grid of 32 px cells (1 cell ≈ 1 m). Mirror-symmetric: player bottom-left, computer top-right.
- Default zoom 1.25 (base view 1280 × 592, landscape; A56 is 2340 × 1080).

## Economy
| Value | Number |
|---|---|
| Start | 200 food, 200 wood, 100 stone, 100 gold, 4 villagers, 1 Town Center |
| Carry per trip | 10 |
| Gather rate per villager | wood 0.6/s, berries 0.9/s, farm 0.7/s, stone 0.45/s, gold 0.45/s |
| Drop sites | Town Center, Depot (all resources) |
| Population | Town Center +10, House +5, maximum 100 |
| Nodes | tree 100 wood, berry bush 150 food, stone 400, gold 400; farm unlimited, 1 villager |

## Epochs (researched at the Town Center, one at a time)
| Epoch | Cost | Time | Unlocks |
|---|---|---|---|
| Idade da Pedra | — | — | villager, spearman, house, farm, depot, barracks, town center |
| Idade do Bronze | 300 food, 150 wood | 30 s | archer, tower |
| Idade do Ferro | 600 food, 300 wood, 200 gold | 40 s | cavalry |
| Idade Medieval | 800 food, 400 stone, 400 gold | 50 s | catapult |

Each epoch adds +15 % hit points and attack to military units (existing ones too) and to tower/town-center arrows; buildings turn from wood to stone colours.

## Units
| Unit | HP | Attack | Range px | Interval s | Speed px/s | Cost | Time s | Pop |
|---|---|---|---|---|---|---|---|---|
| Aldeão (villager) | 50 | 3 | 12 | 1.5 | 70 | 50F | 10 | 1 |
| Lanceiro (spearman) | 110 | 9 | 14 | 1.2 | 75 | 50F 25W | 14 | 1 |
| Arqueiro (archer) | 70 | 7 | 180 | 1.6 | 75 | 40W 30G | 15 | 1 |
| Cavaleiro (cavalry) | 160 | 11 | 16 | 1.4 | 120 | 80F 60G | 20 | 2 |
| Catapulta | 150 | 40 | 260 | 4.0 | 45 | 150W 120G | 30 | 3 |

Counters (damage multipliers): spear ×2.5 vs cavalry · archer ×1.5 vs infantry · cavalry ×2 vs archers and siege · catapult ×3 vs buildings. Non-siege units do ×0.35 to buildings.
Idle soldiers attack enemies within sight (220–300 px) and give up a chase 2.5 × sight from where they stood. Attacked idle soldiers fight back.

## Buildings
| Building | HP | Cost | Build time (1 villager) | Size | Notes |
|---|---|---|---|---|---|
| Centro da Cidade | 2400 | 300W 200S | 60 s | 4×4 | trains villagers, epochs; arrows 6 dmg / 2 s, 210 px |
| Casa | 400 | 40W | 15 s | 2×2 | +5 population |
| Quartel | 1000 | 150W | 30 s | 3×3 | trains spear, archer, cavalry, catapult |
| Depósito | 500 | 100W | 20 s | 2×2 | drop site |
| Fazenda | 200 | 60W | 12 s | 3×3 | walkable, endless food |
| Torre | 900 | 50W 100S | 30 s | 2×2 | Bronze; arrows 8 dmg / 1.8 s, 230 px |

More villagers build faster (progress adds up). Queues hold 5 items; cancel refunds.

## Victory
Destroy the enemy Town Center. Losing yours is defeat.

## Computer opponent (Normal; Easy / Hard in brackets)
- Villager target 18 (12 / 24) + 4 per epoch; splits workers about 50 % food, 34 % wood, 10 % gold, 6 % stone (more gold/stone in later epochs).
- Builds houses when 4 from the cap, a barracks at 6 villagers, a second one in Bronze, a depot by the nearest forest, farms when berries run out, 1 tower (2 on Hard).
- Saves for the next epoch once it has 10 villagers and a guard of 3 + 3 × epoch soldiers.
- Picks units that counter what the player fields most (60 %), else a mix.
- First wave at 300 s (420 / 210) of at least 6 soldiers (4 / 8), +3 per wave (2 / 4), every 150 s, attack-moving to the player's Town Center.
- Defends: soldiers at home attack anyone hitting its buildings within 800 px; villagers hit by soldiers run to the Town Center.
- Gather speed ×1.0 (×0.8 / ×1.2).

## Controls (touch, landscape)
- Tap: select; with units selected, tap ground = move, enemy = attack, resource = gather, own unfinished building = build.
- One-finger drag: pan camera. Pinch: zoom 0.45×–2.2×. Hold 0.4 s then drag: box select. Double tap a unit: all of that kind on screen.
- Minimap (bottom-left): tap/drag to move the camera. Buttons right: Exército (all soldiers), Ocioso (next idle villager), Base.
- Building: select villager(s) → building button → tap map to position the ghost → Construir.
- Desktop: right click commands, mouse wheel zooms.

## On-screen information
Top bar: food, wood, stone, gold, population, epoch, clock, pause. Bottom: minimap, selection panel (name, HP, attack, task, queue progress) with action buttons, shortcut buttons on the right. Alerts appear under the top bar.
