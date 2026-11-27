extends SceneTree
## settings plugin against a fixture addons dir: the headless (CLI) path edits editor_plugins/enabled,
## the editor path goes through EditorInterface (a fake here). Saves are recorded, never written, and
## the setting is restored, so project.godot is untouched.
## Headless: godot --headless --path . --script res://addons/_lib/gdsh_lib/editor/_export_ignore/test/settings_plugin_test.gd
const Sh = preload("res://addons/_lib/gdsh/_ns/gd_sh.gd")
const Host = preload("res://addons/_lib/gdsh/src/core/types.gd").Host
const SETTING = "editor_plugins/enabled"


class Rec:
	var dir:String
	var editor = null
	var saves := 0

class FakeEditor:
	var states := {}
	var calls := []
	func is_plugin_enabled(id:String) -> bool: return states.get(id, false)
	func set_plugin_enabled(id:String, on:bool) -> void:
		calls.append([id, on])
		states[id] = on

class Plugin extends "res://addons/_lib/gdsh_lib/editor/cmd/settings/plugin/plugin.gd":
	var rec:Rec
	func _addons_path() -> String: return rec.dir
	func _editor() -> Object: return rec.editor
	func _host_plugin_id() -> String: return "host"
	func _save() -> int:
		rec.saves += 1
		return OK

class Router extends "res://addons/_lib/gdsh_lib/editor/cmd/settings/settings.gd":
	var rec:Rec
	func _get_commands() -> Dictionary:
		return {"plugin": {&"get_command": func():
			var command = Plugin.new()
			command.rec = rec
			return command}}


func _initialize():
	var res = await run_tests()
	print("\n".join(res.output))
	quit(0 if res.result == 0 else 1)


static func run_tests() -> Dictionary:
	var out := []
	var failures := [0]
	var check = func(ok:bool, label:String):
		if not ok:
			failures[0] += 1
			out.append("FAIL: " + label)
	var saved = ProjectSettings.get_setting(SETTING, PackedStringArray())
	var rec = Rec.new()
	rec.dir = "user://settings-plugin-%s" % Time.get_ticks_usec()
	for id in ["alpha", "beta", "host"]:
		_fixture(rec.dir, id, true)
	_fixture(rec.dir, "broken", false)
	DirAccess.make_dir_recursive_absolute(rec.dir.path_join("not_a_plugin"))
	var alpha = rec.dir.path_join("alpha/plugin.cfg")
	var beta = rec.dir.path_join("beta/plugin.cfg")
	ProjectSettings.set_setting(SETTING, PackedStringArray([beta]))

	var ctx = await _run(rec, "settings plugin --list")
	check.call(ctx.exit_code == 0 and ctx.stdout.contains("disabled alpha") and ctx.stdout.contains("enabled  beta")
		and ctx.stdout.contains("invalid  broken") and not ctx.stdout.contains("not_a_plugin"), "list shows every state: " + ctx.stdout)
	ctx = await _run(rec, "settings plugin")
	check.call(ctx.exit_code == 0 and ctx.stdout.contains("disabled alpha"), "no TUI host: no args prints the list")
	ctx = await _run(rec, "settings plugin alpha beta")
	check.call(ctx.stdout.contains("disabled alpha") and ctx.stdout.contains("enabled  beta") and rec.saves == 0, "ids print their state")

	ctx = await _run(rec, "settings plugin alpha --enable")
	var list = ProjectSettings.get_setting(SETTING)
	check.call(ctx.exit_code == 0 and list == PackedStringArray([beta, alpha]) and rec.saves == 1, "enable appends and saves once: %s" % [list])
	ctx = await _run(rec, "settings plugin alpha --enable")
	check.call(ctx.exit_code == 0 and ctx.stdout.contains("already enabled") and rec.saves == 1, "enabling again is OK and doesn't save")
	ctx = await _run(rec, "settings plugin beta alpha --disable")
	check.call(ctx.exit_code == 0 and ProjectSettings.get_setting(SETTING).is_empty() and rec.saves == 2, "disable removes, one save for many")

	for bad in ["settings plugin nope --enable", "settings plugin broken --enable", "settings plugin alpha --enable --disable",
			"settings plugin alpha --reload", "settings plugin --enable"]:
		ctx = await _run(rec, bad)
		check.call(ctx.exit_code != 0 and ProjectSettings.get_setting(SETTING).is_empty() and rec.saves == 2, "refused unchanged: " + bad)
	ctx = await _run(rec, "settings plugin alpha nope --enable")
	check.call(ctx.exit_code != 0 and ProjectSettings.get_setting(SETTING).is_empty(), "every id is checked before any change")
	ctx = await _run(rec, "settings plugin alpha --enable", Host.MCP)
	check.call(ctx.exit_code != 0 and ctx.stderr.contains("needs the editor or the gdsh CLI"), "no editor and not the CLI: refused")

	var editor = FakeEditor.new()
	editor.states = {"host": true}
	rec.editor = editor
	ctx = await _run(rec, "settings plugin alpha --enable", Host.EDITOR_CONSOLE)
	check.call(ctx.exit_code == 0 and editor.calls == [["alpha", true]] and rec.saves == 2
		and ProjectSettings.get_setting(SETTING).is_empty(), "editor: goes through EditorInterface, no direct write")
	ctx = await _run(rec, "settings plugin alpha --reload", Host.EDITOR_CONSOLE)
	check.call(ctx.exit_code == 0 and editor.calls.slice(1) == [["alpha", false], ["alpha", true]], "editor: reload disables then enables")
	ctx = await _run(rec, "settings plugin host --disable", Host.EDITOR_CONSOLE)
	check.call(ctx.exit_code != 0 and editor.states.host and ctx.stderr.contains("can't disable itself"), "editor: the host plugin is protected")

	ProjectSettings.set_setting(SETTING, saved)
	for id in DirAccess.get_directories_at(rec.dir):
		var dir = rec.dir.path_join(id)
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(rec.dir)
	out.append("settings plugin: %d failed" % failures[0])
	return {"result": failures[0], "output": out}


static func _run(rec:Rec, text:String, host:String = Host.CLI) -> Sh.Context:
	var ctx = Sh.Context.new()
	ctx.variables[Host.VAR] = host
	var router = Router.new()
	router.rec = rec
	ctx.scopes["settings"] = {"script": router}
	await Sh.Execute.execute_command_multiline(text, ctx)
	return ctx


static func _fixture(root:String, id:String, valid:bool) -> void:
	var dir = root.path_join(id)
	DirAccess.make_dir_recursive_absolute(dir)
	var config = ConfigFile.new()
	config.set_value("plugin", "name", id.capitalize())
	config.set_value("plugin", "script", "plugin.gd")
	config.save(dir.path_join("plugin.cfg"))
	if valid:
		FileAccess.open(dir.path_join("plugin.gd"), FileAccess.WRITE).store_string("@tool\nextends EditorPlugin\n")
