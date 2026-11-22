# gdsh_lib editor

gdsh commands for driving the Godot editor, shared by
[Editor Console](https://github.com/brohd11/Godot-Editor-Console) and the
[mcp-sh-godot](https://github.com/brohd11/mcp-sh-godot) plugin.

- `editor`: play/stop, open, scan, reveal, restart, the editor's undo/redo, scenes (new, save,
  reload, root, select), the current script, `state`, `screenshot`, text `search` and `plugin`
  (enable/disable addons).
- `settings`: project settings (`psetting`), editor settings (`esetting`) and `mainscene`.
- `resource`: `new`, `duplicate`, `uid`, `deps`, `search` and `reload_script`.

The commands are editor-only (`EditorInterface`). Add them to a `GDSh.Host` through the
manifest, which also makes exporters bundle every command:

```gdscript
const EditorManifest = preload("res://addons/_lib/gdsh_lib/editor/cmd/manifest.gd")

host.add_command_dir(EditorManifest.resource_path.get_base_dir())
```

Optional host hooks, set in `host_data`:
- `file_paths`: a cached project file list, used by `editor search` and `resource search`.
- `host_plugin_id`: the addon that hosts the commands, which `editor plugin` won't let you
  disable. Without it, the plugin that bundles this library is found from the script's path.
