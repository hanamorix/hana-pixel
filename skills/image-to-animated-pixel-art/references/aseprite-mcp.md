# Aseprite MCP

The skill drives Aseprite through the [aseprite-mcp](https://github.com/diivi/aseprite-mcp) server.

## Setup
1. Install Aseprite.
2. Clone aseprite-mcp and follow its README (it runs with uv). Point `ASEPRITE_PATH` at the Aseprite binary if it
   is not on PATH, for example `/Applications/Aseprite.app/Contents/MacOS/aseprite` on macOS or
   `C:\Program Files\Aseprite\Aseprite.exe` on Windows.
3. Register it in Claude Code as an MCP server named `aseprite`.

## Tips
- Long Lua: keep the script in a file and call `run_lua_script` with a launcher that sets globals and then
  `dofile([[path]])`.
- Batch mode: always `saveAs`; `app.open` switches the active sprite.
- Speed: 48 frames of ~65k moving px with fractional sampling takes 10-20 s.
- Looking: `view_sprite` with `region` and `frames` for flip-books, `read_rows` for pixels as letters,
  `export_animation` at scale 3 for GIF previews.
- Comparing: a short Lua loop over two files counting differing pixels proves "unchanged" after a refactor.
