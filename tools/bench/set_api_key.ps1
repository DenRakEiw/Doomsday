<#
.SYNOPSIS
    Stores a benchmark API key as a user environment variable, entered in a small dialog.

.DESCRIPTION
    Opens a Windows Forms dialog with a password box (Ctrl+V pastes; "Show key" reveals what
    was pasted) and OK / Cancel. On OK the key is stored as a *user* environment variable -
    the only place the benchmark tool reads it from (docs/specs/benchmark.md section 0 item 7, section 17.8).

    The key is never printed, logged or written anywhere else. The script reports only that it
    was saved, how many characters it has, and whether it starts with the prefix the service's
    keys are known to have.

    Only processes started after this see the new variable: open a new PowerShell window (and
    restart an editor or terminal that should see it) before running the benchmark.

.PARAMETER Name
    The variable to set: OPENROUTER_API_KEY (chat models, via OpenRouter) or TYPESAFE_API_KEY
    (TypeSafe's decision model Jev).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\bench\set_api_key.ps1 -Name TYPESAFE_API_KEY
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('OPENROUTER_API_KEY', 'TYPESAFE_API_KEY')]
    [string]$Name
)

$ErrorActionPreference = 'Stop'

# The prefix each service's keys are known to start with; $null when none is published.
$ExpectedPrefix = @{
    'OPENROUTER_API_KEY' = 'sk-or-'
    'TYPESAFE_API_KEY'   = $null
}

# Windows Forms and the clipboard need a single-threaded apartment; PowerShell 7 runs
# multi-threaded, so hand over to Windows PowerShell with -STA there.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $PSCommandPath -Name $Name
    exit $LASTEXITCODE
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Doomsday benchmark - $Name"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.AutoSize = $true
$form.AutoSizeMode = 'GrowAndShrink'
$form.Padding = New-Object System.Windows.Forms.Padding(12)

$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.AutoSize = $true
$layout.ColumnCount = 1
$layout.Dock = 'Fill'
$form.Controls.Add($layout)

$label = New-Object System.Windows.Forms.Label
$label.AutoSize = $true
$label.Text = "Paste the key for $Name (Ctrl+V). It is stored as a user environment variable."
$layout.Controls.Add($label)

$box = New-Object System.Windows.Forms.TextBox
$box.UseSystemPasswordChar = $true
$box.Width = 460
$box.ShortcutsEnabled = $true
$layout.Controls.Add($box)

$show = New-Object System.Windows.Forms.CheckBox
$show.AutoSize = $true
$show.Text = 'Show key'
$show.Add_CheckedChanged({ $box.UseSystemPasswordChar = -not $show.Checked })
$layout.Controls.Add($show)

$buttons = New-Object System.Windows.Forms.FlowLayoutPanel
$buttons.AutoSize = $true
$buttons.FlowDirection = 'RightToLeft'
$buttons.Dock = 'Fill'
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancel'
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$ok = New-Object System.Windows.Forms.Button
$ok.Text = 'OK'
$ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
$buttons.Controls.Add($cancel)
$buttons.Controls.Add($ok)
$layout.Controls.Add($buttons)

$form.AcceptButton = $ok
$form.CancelButton = $cancel
$form.Add_Shown({ $form.Activate(); $box.Focus() })

$result = $form.ShowDialog()
$key = $box.Text.Trim()
$form.Dispose()

if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Cancelled - $Name was not changed."
    exit 1
}
if ([string]::IsNullOrEmpty($key)) {
    Write-Host "No key entered - $Name was not changed."
    exit 1
}

[System.Environment]::SetEnvironmentVariable($Name, $key, 'User')

$prefix = $ExpectedPrefix[$Name]
if ($null -eq $prefix) {
    $prefixLine = 'starts with the expected prefix: not checked (the service publishes none)'
} elseif ($key.StartsWith($prefix)) {
    $prefixLine = "starts with the expected prefix ($prefix): yes"
} else {
    $prefixLine = "starts with the expected prefix ($prefix): no - check that the whole key was pasted"
}
Write-Host "$Name saved, $($key.Length) characters, $prefixLine."
Write-Host 'Only processes started from now on see it: open a new PowerShell window before running the benchmark.'
$key = $null
exit 0
