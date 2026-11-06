# Shared helpers of the benchmark scripts (docs/specs/benchmark.md section 18). Dot-source it:
#   . (Join-Path $PSScriptRoot "bench_common.ps1")
# Nothing here prints a key: Get-BenchKey only tells whether one was found.

function Get-BenchRoot {
	# The game repository: two levels above tools/bench.
	return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

function Resolve-BenchGodot([string]$Given) {
	# The Godot console executable: -Godot, else $env:GODOT, else the per-machine
	# .claude/settings.local.json (env.GODOT), else `godot` on PATH.
	if ($Given) { return $Given }
	if ($env:GODOT) { return $env:GODOT }
	$settings = Join-Path (Get-BenchRoot) ".claude\settings.local.json"
	if (Test-Path $settings) {
		try {
			$json = Get-Content -Raw -Encoding UTF8 $settings | ConvertFrom-Json
			if ($json.env -and $json.env.GODOT) { return [string]$json.env.GODOT }
		} catch { }
	}
	$found = Get-Command godot -ErrorAction SilentlyContinue
	if ($found) { return $found.Source }
	throw "Godot not found: pass -Godot <path to the *_console.exe>, or set GODOT."
}

function Get-DoomsdayCredentialType {
	if (-not ("DoomsdayCredential" -as [type])) {
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
	[DllImport("advapi32.dll")]
	static extern void CredFree(IntPtr buffer);
	const int Generic = 1;
	const int LocalMachine = 2;
	public static bool Write(string target, string user, string secret) {
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
			return CredWrite(ref credential, 0);
		} finally {
			Marshal.FreeHGlobal(credential.CredentialBlob);
		}
	}
	public static string Read(string target) {
		IntPtr pointer;
		if (!CredRead(target, Generic, 0, out pointer)) { return null; }
		try {
			Credential credential = (Credential)Marshal.PtrToStructure(pointer, typeof(Credential));
			return Marshal.PtrToStringUni(credential.CredentialBlob, credential.CredentialBlobSize / 2);
		} finally {
			CredFree(pointer);
		}
	}
}
'@
	}
}

function Import-BenchKey([string]$Name) {
	# Makes the key visible to the child processes: from this process's
	# environment, else from the user's (HKCU\Environment, where set_api_key.ps1
	# stores it - a window opened before that does not see it), else for
	# OPENROUTER_API_KEY from the Windows Credential Manager entry Doomsday/OpenRouter
	# that the in-game key dialog writes. Returns whether a key was found;
	# the key itself is never printed or returned.
	$value = [Environment]::GetEnvironmentVariable($Name, "Process")
	if (-not $value) {
		$value = [Environment]::GetEnvironmentVariable($Name, "User")
		if (-not $value -and $Name -eq "OPENROUTER_API_KEY") {
			try {
				Get-DoomsdayCredentialType
				$value = [DoomsdayCredential]::Read("Doomsday/OpenRouter")
			} catch { }
		}
		if ($value) { [Environment]::SetEnvironmentVariable($Name, $value, "Process") }
	}
	return [bool]$value
}

function Invoke-BenchGodot([string]$Godot, [string[]]$Arguments) {
	# Runs a headless Godot tool in the game repository and returns
	# @{ Code = <exit code>; Lines = <stdout lines> }.
	# "Continue": in Windows PowerShell 5.1 a native program's stderr would
	# otherwise become a terminating error; the exit code decides.
	$ErrorActionPreference = "Continue"
	$root = Get-BenchRoot
	$lines = & $Godot --headless --path $root @Arguments 2>$null
	return @{ Code = $LASTEXITCODE; Lines = @($lines) }
}

function Publish-BenchBoard([string]$Board, [scriptblock]$AfterRebase = $null) {
	# Pushes the leaderboard clone's HEAD to origin's main (benchmark.md section 18.6).
	# Refused (someone pushed meanwhile): one `pull --rebase`, then once more. A rebase
	# that stops on a conflict is aborted - the clone is left on its own commits, never
	# mid-rebase - and nothing is pushed. After a clean rebase $AfterRebase runs (the local
	# verification rebuilds the board on the new base) and returns "" or why to stop.
	# Returns @{ Code = 0 | 1; Message = <why not> }.
	$ErrorActionPreference = "Continue"
	$null = & git -C $Board push -q origin HEAD:main 2>&1
	if ($LASTEXITCODE -eq 0) { return @{ Code = 0; Message = "" } }
	$pulled = @(& git -C $Board pull -q --rebase origin main 2>&1 | ForEach-Object { [string]$_ })
	if ($LASTEXITCODE -ne 0) {
		$null = & git -C $Board rebase --abort 2>&1
		return @{ Code = 1; Message = ("the push was refused and the rebase onto origin's main stopped (" +
			(($pulled | Select-Object -First 2) -join " ") + ") - it was aborted, nothing was pushed, the commits are local in $Board; pull and resolve by hand, then submit again") }
	}
	if ($AfterRebase) {
		$reason = [string](@(& $AfterRebase) | Select-Object -Last 1)
		if ($reason) { return @{ Code = 1; Message = $reason } }
	}
	$null = & git -C $Board push -q origin HEAD:main 2>&1
	if ($LASTEXITCODE -ne 0) {
		return @{ Code = 1; Message = "the push was refused twice - the commits are local in $Board" }
	}
	return @{ Code = 0; Message = "" }
}

function Get-BenchSlug([string]$Model) {
	# benchmark.md section 10.2's slug: lower-case, `/` -> `--`, anything else outside [a-z0-9._-] -> `-`.
	$lowered = $Model.ToLowerInvariant().Replace("/", "--")
	return ($lowered -replace "[^a-z0-9._-]", "-")
}
