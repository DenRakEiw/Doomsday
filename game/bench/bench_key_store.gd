class_name BenchKeyStore
extends RefCounted
## The player's OpenRouter key in the operating system's credential store
## (docs/specs/benchmark.md §19.2): the Windows Credential Manager as the generic
## credential `Doomsday/OpenRouter`, the desktop keyring through `secret-tool` on
## Linux, nothing elsewhere. No native extension: Windows is reached through
## PowerShell calling `advapi32`, Linux through `secret-tool`.
##
## The key is never an argument of a process (other processes can read those),
## never in an environment variable, never in a file, never in a log line: it
## travels on a child's stdin (save) or stdout (load) only. Every call blocks for
## up to a few seconds (PowerShell compiles its helper class first), so the
## interface calls it off the main thread.
##
## Tests set `backend_override` and never touch the real store.

const KIND_WINDOWS: String = "windows"
const KIND_LINUX: String = "linux"
const KIND_SESSION: String = "session"

## What a backend is asked to do, and what it answers (`backend_override` too).
const OP_LOAD: String = "load"
const OP_SAVE: String = "save"
const OP_REMOVE: String = "remove"
const STATUS_OK: String = "ok"
const STATUS_NONE: String = "none"
const STATUS_ERROR: String = "error"
const FIELD_STATUS: String = "status"
const FIELD_KEY: String = "key"

const OS_WINDOWS: String = "Windows"
const OS_LINUX: String = "Linux"
const FEATURE_PC: String = "pc"
const FEATURE_WEB: String = "web"

## §19.2: the Windows credential's name and user.
const WINDOWS_TARGET: String = "Doomsday/OpenRouter"
const WINDOWS_USER: String = "openrouter"
const POWERSHELL: String = "powershell.exe"
const POWERSHELL_ARGS: Array[String] = ["-NoProfile", "-NonInteractive", "-ExecutionPolicy",
	"Bypass", "-EncodedCommand"]
## The script's exit codes: found / saved / removed, nothing stored, anything else.
const EXIT_OK: int = 0
const EXIT_NONE: int = 2
## Where the operation goes in `WINDOWS_SCRIPT`.
const OP_MARK: String = "@OP@"
const TARGET_MARK: String = "@TARGET@"
const USER_MARK: String = "@USER@"
## Generic credential, persisted for this user on this computer
## (`CRED_TYPE_GENERIC`, `CRED_PERSIST_LOCAL_MACHINE`); `ERROR_NOT_FOUND`.
## A save reads the key from stdin, a load writes it to stdout; nothing else
## is ever printed.
const WINDOWS_SCRIPT: String = """$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DoomsdayCredential {
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	struct Credential {
		public int Flags; public int Type; public string TargetName; public string Comment;
		public long LastWritten; public int CredentialBlobSize; public IntPtr CredentialBlob;
		public int Persist; public int AttributeCount; public IntPtr Attributes;
		public string TargetAlias; public string UserName;
	}
	[DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
	static extern bool CredWrite(ref Credential credential, int flags);
	[DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
	static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
	[DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
	static extern bool CredDelete(string target, int type, int flags);
	[DllImport("advapi32.dll")]
	static extern void CredFree(IntPtr buffer);
	const int Generic = 1;
	const int LocalMachine = 2;
	const int NotFound = 1168;
	public static int Write(string target, string user, string secret) {
		byte[] blob = System.Text.Encoding.Unicode.GetBytes(secret);
		Credential credential = new Credential();
		credential.Type = Generic;
		credential.TargetName = target;
		credential.UserName = user;
		credential.Persist = LocalMachine;
		credential.CredentialBlobSize = blob.Length;
		credential.CredentialBlob = Marshal.AllocHGlobal(blob.Length);
		try {
			Marshal.Copy(blob, 0, credential.CredentialBlob, blob.Length);
			return CredWrite(ref credential, 0) ? 0 : 1;
		} finally {
			Marshal.FreeHGlobal(credential.CredentialBlob);
		}
	}
	public static string Read(string target) {
		IntPtr pointer;
		if (!CredRead(target, Generic, 0, out pointer)) {
			return Marshal.GetLastWin32Error() == NotFound ? null : "";
		}
		try {
			Credential credential = (Credential)Marshal.PtrToStructure(pointer, typeof(Credential));
			return Marshal.PtrToStringUni(credential.CredentialBlob, credential.CredentialBlobSize / 2);
		} finally {
			CredFree(pointer);
		}
	}
	public static int Delete(string target) {
		if (CredDelete(target, Generic, 0)) { return 0; }
		return Marshal.GetLastWin32Error() == NotFound ? 2 : 1;
	}
}
'@
$op = '@OP@'
if ($op -eq 'save') {
	$secret = [Console]::In.ReadLine()
	if ([string]::IsNullOrEmpty($secret)) { exit 1 }
	exit [DoomsdayCredential]::Write('@TARGET@', '@USER@', $secret)
}
if ($op -eq 'load') {
	$found = [DoomsdayCredential]::Read('@TARGET@')
	if ($found -eq $null) { exit 2 }
	if ($found -eq '') { exit 1 }
	[Console]::Out.Write($found)
	exit 0
}
if ($op -eq 'remove') { exit [DoomsdayCredential]::Delete('@TARGET@') }
exit 1
"""

## §19.2: the Linux keyring's attributes and label.
const SECRET_TOOL: String = "secret-tool"
const LINUX_ATTRIBUTES: Array[String] = ["application", "doomsday", "service", "openrouter"]
const LINUX_LABEL: String = "--label=Doomsday OpenRouter key"
const SHELL: String = "sh"
const SHELL_WHICH: Array[String] = ["-c", "command -v secret-tool"]

## How long a save waits for its child before it gives up.
const WAIT_MS: int = 20000
const POLL_MS: int = 20

## The test seam: `func(op: String, key: String) -> Dictionary` answering
## `{"status": "ok" | "none" | "error", "key": String}`. Unset, the real store.
var backend_override: Callable = Callable()

## The tests' feature seam for §19.1: −1 asks the build, 0 answers no, 1 yes —
## so a desktop suite can see the web's settings and lists, and the other way.
static var supported_override: int = -1

## Set once a call found the store missing or refusing: `kind()` is then
## `session` — the key lives in memory only (`BenchJobs.session_key`).
var _unavailable: bool = false
var _linux_checked: bool = false


## §19.1: a desktop build on Windows or Linux.
static func is_supported() -> bool:
	if supported_override >= 0:
		return supported_override == 1
	return supported_on(OS.has_feature(FEATURE_PC), OS.has_feature(FEATURE_WEB), OS.get_name())


## The same answer for a given feature set — the seam `is_supported` is tested by.
static func supported_on(is_pc: bool, is_web: bool, os_name: String) -> bool:
	return is_pc and not is_web and (os_name == OS_WINDOWS or os_name == OS_LINUX)


## Which sentence the key dialog shows: where the key is kept.
func kind() -> String:
	if backend_override.is_valid():
		return KIND_SESSION if _unavailable else _os_kind()
	if not is_supported() or _unavailable:
		return KIND_SESSION
	if OS.get_name() == OS_LINUX and not _linux_checked:
		_linux_checked = true
		var output: Array = []
		if OS.execute(SHELL, SHELL_WHICH, output) != 0:
			_unavailable = true
			return KIND_SESSION
	return _os_kind()


## The stored key, or "" when there is none or on any failure.
func load() -> String:
	var answer: Dictionary = _call(OP_LOAD, "")
	if str(answer.get(FIELD_STATUS, STATUS_ERROR)) != STATUS_OK:
		return ""
	return str(answer.get(FIELD_KEY, ""))


## False when the store refused or is missing: the caller keeps the key for the
## session instead (§19.7).
func save(key: String) -> bool:
	if key.is_empty():
		return false
	var saved: bool = str(_call(OP_SAVE, key).get(FIELD_STATUS, STATUS_ERROR)) == STATUS_OK
	if not saved:
		_unavailable = true
	return saved


## True when nothing is stored afterwards (nothing stored before counts too).
func remove() -> bool:
	var status: String = str(_call(OP_REMOVE, "").get(FIELD_STATUS, STATUS_ERROR))
	return status == STATUS_OK or status == STATUS_NONE


## `powershell.exe`'s arguments for one operation: the script, never the key.
static func windows_arguments(op: String) -> PackedStringArray:
	var script: String = WINDOWS_SCRIPT.replace(OP_MARK, op).replace(TARGET_MARK, WINDOWS_TARGET) \
		.replace(USER_MARK, WINDOWS_USER)
	var arguments: PackedStringArray = PackedStringArray(POWERSHELL_ARGS)
	# -EncodedCommand takes UTF-16LE in Base64: no quoting survives otherwise.
	arguments.append(Marshalls.raw_to_base64(script.to_utf16_buffer()))
	return arguments


## `secret-tool`'s arguments for one operation: the attributes, never the key.
static func linux_arguments(op: String) -> PackedStringArray:
	var arguments: PackedStringArray = []
	match op:
		OP_SAVE:
			arguments.append_array(["store", LINUX_LABEL])
		OP_LOAD:
			arguments.append("lookup")
		_:
			arguments.append("clear")
	arguments.append_array(PackedStringArray(LINUX_ATTRIBUTES))
	return arguments


static func _os_kind() -> String:
	return KIND_LINUX if OS.get_name() == OS_LINUX else KIND_WINDOWS


func _call(op: String, key: String) -> Dictionary:
	if backend_override.is_valid():
		var answer: Variant = backend_override.call(op, key)
		return answer if typeof(answer) == TYPE_DICTIONARY else _status(STATUS_ERROR)
	if kind() == KIND_SESSION:
		return _status(STATUS_ERROR)
	if OS.get_name() == OS_WINDOWS:
		return _run(POWERSHELL, windows_arguments(op), op, key, "\n")
	return _run(SECRET_TOOL, linux_arguments(op), op, key, "")


## One child process. A save hands the key over on stdin and reads nothing back;
## a load reads it from stdout.
func _run(program: String, arguments: PackedStringArray, op: String, key: String,
		line_end: String) -> Dictionary:
	if op != OP_SAVE:
		var output: Array = []
		var code: int = OS.execute(program, arguments, output)
		if code == EXIT_OK:
			var text: String = str(output[0]) if not output.is_empty() else ""
			# secret-tool ends its output with a line break; a key has none.
			return {FIELD_STATUS: STATUS_OK, FIELD_KEY: text.strip_edges()}
		# secret-tool answers 1 for "nothing stored" and for every failure alike.
		return _status(STATUS_NONE if code == EXIT_NONE or program == SECRET_TOOL else STATUS_ERROR)
	var child: Dictionary = OS.execute_with_pipe(program, arguments, false)
	if child.is_empty():
		return _status(STATUS_ERROR)
	var pipe: FileAccess = child["stdio"]
	var pid: int = int(child["pid"])
	pipe.store_string(key + line_end)
	pipe.flush()
	# The child reads to the line break (PowerShell) or to the end (secret-tool).
	pipe.close()
	var waited: int = 0
	while OS.is_process_running(pid) and waited < WAIT_MS:
		OS.delay_msec(POLL_MS)
		waited += POLL_MS
	if OS.is_process_running(pid):
		OS.kill(pid)
		return _status(STATUS_ERROR)
	return _status(STATUS_OK if OS.get_process_exit_code(pid) == EXIT_OK else STATUS_ERROR)


static func _status(status: String) -> Dictionary:
	return {FIELD_STATUS: status, FIELD_KEY: ""}
