extends SceneTree
## Every command compiles from the manifest, has a name, and the namespaces route to their
## subcommands. Headless (isolated): python3 addons/_lib/gdsh_lib/editor/_export_ignore/test/run_headless.py
## Editor console: `test res://addons/_lib/gdsh_lib/editor/_export_ignore/test`.
const Manifest = preload("res://addons/_lib/gdsh_lib/editor/cmd/manifest.gd")
const Sh = preload("res://addons/_lib/gdsh/_ns/gd_sh.gd")

const EXPECTED = {
	"editor": ["play", "stop", "open", "scan", "scene", "script", "state", "search", "undo", "redo", "plugin"],
	"settings": ["psetting", "esetting", "mainscene"],
	"resource": ["new", "duplicate", "uid", "deps", "search", "reload_script"],
}


func _initialize():
	var res = run_tests()
	print("\n".join(res.output))
	quit(0 if res.result == 0 else 1)


static func run_tests() -> Dictionary:
	var out := []
	var failures := 0
	for script in Manifest.COMMANDS + [Manifest.EDITOR, Manifest.SETTINGS, Manifest.RESOURCE]:
		if not (script as GDScript).can_instantiate():
			out.append("FAIL compile: " + script.resource_path)
			failures += 1
		elif str(script.get_command_name()).is_empty():
			out.append("FAIL unnamed: " + script.resource_path)
			failures += 1
	for ns in Manifest.NAMESPACES:
		var name = str(ns.get_command_name())
		var subcommands = ns.new().get_commands().keys()
		for expected in EXPECTED.get(name, []):
			if not expected in subcommands:
				out.append("FAIL %s: no subcommand %s (has %s)" % [name, expected, subcommands])
				failures += 1
	# The namespaces load into a plain GDSh host, the way the mcp-sh-godot plugin uses them.
	var host = Sh.Host.new({})
	for ns in Manifest.NAMESPACES:
		host.add_command(ns.resource_path)
	var listed = host.host_commands().map(func(entry): return entry.name)
	for name in EXPECTED:
		if not name in listed:
			out.append("FAIL host: %s not listed" % name)
			failures += 1
	out.append("%d commands; %d failed" % [Manifest.COMMANDS.size() + 3, failures])
	return {"result": failures, "output": out}
