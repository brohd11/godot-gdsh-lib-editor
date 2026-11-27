# gdsh_lib editor

gdsh commands for driving the Godot editor, shared by
[Editor Console](https://github.com/brohd11/Godot-Editor-Console) and the
[mcp-sh-godot](https://github.com/brohd11/mcp-sh-godot) plugin.

Install: see [Command packages](https://github.com/brohd11/godot-gdsh/blob/main/_export_ignore/docs/packages.md) in the gdsh repo.

- `editor`: play/stop, open, scan, reveal, restart, the editor's undo/redo, scenes (new, save,
  reload, root, select), the current script, `state`, `screenshot` and text `search`.
- `settings`: project settings (`psetting`), editor settings (`esetting`), `mainscene` and `plugin`
  (list, enable or disable addons; an interactive list in Editor Console).
- `resource`: `new`, `duplicate`, `uid`, `deps`, `search` and `reload_script`.

The commands are editor-only (`EditorInterface`), except `settings psetting`, `mainscene` and
`plugin`, which the gdsh CLI bundles: there `settings plugin x --enable` edits project.godot, so a
plugin you just installed can be turned on without opening the editor.

Add them to a `GDSh.Host` through the manifest, which also makes exporters bundle every command:

```gdscript
const EditorManifest = preload("res://addons/_lib/gdsh_lib/editor/cmd/manifest.gd")

host.add_command_dir(EditorManifest.resource_path.get_base_dir())
```

Optional host hooks, set in `host_data`:
- `file_paths`: a cached project file list, used by `editor search` and `resource search`.
- `host_plugin_id`: the addon that hosts the commands, which `settings plugin` won't let you
  disable. Without it, the plugin that bundles this library is found from the script's path.
