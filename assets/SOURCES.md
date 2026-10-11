# Asset provenance

Textures and WAV sound files were downloaded from the public community project
[darrenprx/lolPing](https://github.com/darrenprx/lolPing) at commit
`86a0c4696d3d716d3da05f4e08a05587a7b9b651`.

The upstream project identifies these files as extracted League of Legends
assets owned by Riot Games. We have not independently extracted or verified
them against an installed game client. The exact URLs, sizes, and SHA-256
checksums are recorded in `manifest.json`.

`UPSTREAM-LICENSE.txt` preserves the upstream notice. Its MIT license covers
upstream code, **not** these Riot textures or sounds. Public availability is
not a transfer of copyright or an independent permission to redistribute them.
This local prototype is not affiliated with or endorsed by Riot Games.

The native wheel geometry, metallic centre, texture tinting, timing, ripple
animation and application code are implemented in this project. In particular,
the animation is a recreation using the community-sourced textures, not a
claim to reproduce the game's original particle system exactly.

Missing ping: `enemy_missing.png` + `MIA.wav`.
Eight-way icon and sound mappings are defined in `src/main.m`.
