extends Node
class_name WebModLoader
## Imports a mod folder from the user's disk into the sandboxed VFS on web exports.
##
## Browsers cannot give Godot a path-addressable handle to a folder on disk, so we
## copy the picked folder into [code]user://mods/active[/code] (which [GameData] then
## treats like any other data dir). [method begin_refresh] re-reads the folder so an
## edited mod can be pulled in again without restarting.

## Emitted once every file from the picked folder has been written to [member ACTIVE_DIR].
signal mod_imported(dir_path: String, display_name: String)
## Emitted when the user dismisses the picker or the folder is empty/unreadable.
signal mod_cancelled()

const ACTIVE_DIR: String = "user://mods/active"
const INCOMING_DIR: String = "user://mods/incoming"

# Status codes sent as the 3rd argument of the per-file JS callback.
const _STATUS_MORE := 0    # A file, with more to follow.
const _STATUS_LAST := 1    # The final file of the batch.
const _STATUS_ABORT := 2   # Picker cancelled, or folder empty/unreadable.

## Browser-side glue. Prefers the File System Access API (keeps a directory handle so
## refreshes need no re-navigation) and falls back to a `webkitdirectory` <input>.
const _JS_SOURCE := """
window.EscortMod = (function () {
	var dirHandle = null;

	function emitFile(path, b64, status, total) {
		if (window.godotOnModFile) window.godotOnModFile(path, b64, status, total);
	}
	function emitName(name) {
		if (window.godotOnModName) window.godotOnModName(name);
	}

	function toBase64(bytes) {
		var binary = '';
		var chunk = 0x8000;
		for (var i = 0; i < bytes.length; i += chunk) {
			binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
		}
		return btoa(binary);
	}

	function send(files, name) {
		emitName(name || '');
		var total = files.length;
		if (total === 0) { emitFile('', '', 2, 0); return; }
		for (var i = 0; i < total; i++) {
			emitFile(files[i].path, toBase64(files[i].data), i === total - 1 ? 1 : 0, total);
		}
	}

	async function collectHandle(handle, prefix, files) {
		for await (const entry of handle.values()) {
			if (entry.kind === 'directory') {
				await collectHandle(entry, prefix + entry.name + '/', files);
			} else {
				var file = await entry.getFile();
				files.push({ path: prefix + entry.name, data: new Uint8Array(await file.arrayBuffer()) });
			}
		}
	}

	async function readHandle() {
		if (dirHandle.queryPermission) {
			var perm = await dirHandle.queryPermission({ mode: 'read' });
			if (perm !== 'granted') perm = await dirHandle.requestPermission({ mode: 'read' });
			if (perm !== 'granted') { emitFile('', '', 2, 0); return; }
		}
		var files = [];
		await collectHandle(dirHandle, '', files);
		send(files, dirHandle.name);
	}

	function pickInput() {
		var input = document.createElement('input');
		input.type = 'file';
		input.webkitdirectory = true;
		input.multiple = true;
		input.style.display = 'none';
		document.body.appendChild(input);
		input.addEventListener('change', async function () {
			var picked = Array.from(input.files);
			document.body.removeChild(input);
			if (picked.length === 0) { emitFile('', '', 2, 0); return; }
			var rootName = (picked[0].webkitRelativePath || '').split('/')[0];
			var files = [];
			for (var i = 0; i < picked.length; i++) {
				var f = picked[i];
				var rel = f.webkitRelativePath || f.name;
				var slash = rel.indexOf('/');
				if (slash >= 0) rel = rel.substring(slash + 1);
				files.push({ path: rel, data: new Uint8Array(await f.arrayBuffer()) });
			}
			send(files, rootName);
		});
		input.click();
	}

	async function pick() {
		if (window.showDirectoryPicker) {
			try {
				dirHandle = await window.showDirectoryPicker();
			} catch (e) {
				if (e && e.name === 'AbortError') { emitFile('', '', 2, 0); return; }
				dirHandle = null;
				pickInput();
				return;
			}
			await readHandle();
			return;
		}
		pickInput();
	}

	return {
		pick: pick,
		refresh: function () { if (dirHandle) { readHandle(); } else { pick(); } }
	};
})();
"""

var _file_callback: JavaScriptObject
var _name_callback: JavaScriptObject
var _pending_name: String = ""


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(_JS_SOURCE, true)
	var window := JavaScriptBridge.get_interface("window")
	_file_callback = JavaScriptBridge.create_callback(_on_js_file)
	_name_callback = JavaScriptBridge.create_callback(_on_js_name)
	window.godotOnModFile = _file_callback
	window.godotOnModName = _name_callback


## Opens the browser folder picker so the user can choose a mod to import.
func begin_pick() -> void:
	_prepare_incoming()
	JavaScriptBridge.eval("window.EscortMod.pick();", true)


## Re-reads the previously picked folder, pulling in any edits the user has made.
func begin_refresh() -> void:
	_prepare_incoming()
	JavaScriptBridge.eval("window.EscortMod.refresh();", true)


func _on_js_name(args: Array) -> void:
	_pending_name = str(args[0]) if args.size() > 0 else ""


func _on_js_file(args: Array) -> void:
	var path: String = str(args[0]) if args.size() > 0 else ""
	var b64: String = str(args[1]) if args.size() > 1 else ""
	var status: int = int(args[2]) if args.size() > 2 else _STATUS_ABORT

	if status == _STATUS_ABORT:
		_remove_dir_recursive(INCOMING_DIR)
		mod_cancelled.emit()
		return

	if not path.is_empty():
		_write_incoming_file(path, b64)

	if status == _STATUS_LAST:
		_finalize()


func _finalize() -> void:
	_remove_dir_recursive(ACTIVE_DIR)
	DirAccess.make_dir_recursive_absolute(ACTIVE_DIR.get_base_dir())
	var err := DirAccess.rename_absolute(INCOMING_DIR, ACTIVE_DIR)
	if err != OK:
		push_error("WebModLoader: failed to activate imported mod (error %d)" % err)
		mod_cancelled.emit()
		return
	mod_imported.emit(ACTIVE_DIR, _pending_name)


func _prepare_incoming() -> void:
	_remove_dir_recursive(INCOMING_DIR)
	DirAccess.make_dir_recursive_absolute(INCOMING_DIR)


func _write_incoming_file(rel_path: String, b64: String) -> void:
	var full := INCOMING_DIR + "/" + rel_path
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var file := FileAccess.open(full, FileAccess.WRITE)
	if file == null:
		push_error("WebModLoader: failed to write " + full)
		return
	file.store_buffer(Marshalls.base64_to_raw(b64))
	file.close()


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full := path + "/" + entry
			if dir.current_is_dir():
				_remove_dir_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
