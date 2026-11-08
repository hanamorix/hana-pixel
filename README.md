# hana-pixel

Claude Code skills for turning an image into detailed pixel art in Aseprite and animating it smoothly.

**image-to-animated-pixel-art** takes a source image (a painting, an illustration) to a pixel-art still that stays
true to the source, then to a seamless idle loop: breathing, blink, hair and cloth sway, hands or limbs that move
as exact copies, soft-body bounce, shine, glints and water. Every animation is checked by measurement before it is
shown (flicker, pops, jumps, a heat map), because pixel art "breaks" in ways a single frame never shows.

## Install

In Claude Code, paste this repo's GitHub link after the marketplace command, then install the plugin:

```
/plugin marketplace add <link to this repo>
/plugin install hana-pixel@hana-pixel
```

Or copy `skills/image-to-animated-pixel-art` into `~/.claude/skills/` by hand.

## Requirements

- [Aseprite](https://www.aseprite.org/)
- The [aseprite-mcp](https://github.com/diivi/aseprite-mcp) server, registered in Claude Code as `aseprite`
  (setup notes in `skills/image-to-animated-pixel-art/references/aseprite-mcp.md`)

## Use

Ask Claude to turn an image into pixel art, or to animate a pixel-art piece. The skill runs a short brief, builds
the still with check-ins (hands, face, outlines), then the blink, the motion and the effects, each shown as a GIF
with a close-up before you approve it.

Your own taste (how subtle the motion is, what must stay still, how you like check-ins) belongs in your own
`CLAUDE.md` or a file it points to; the skill reads it first.

## Layout

```
.claude-plugin/        plugin and marketplace manifests
skills/image-to-animated-pixel-art/
  SKILL.md             workflow and checks
  references/          still recipe, motion without breaks, Aseprite MCP setup
  scripts/             Aseprite Lua scripts (run through the MCP)
```

## License

MIT
