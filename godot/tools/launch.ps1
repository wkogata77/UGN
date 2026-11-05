param(
    [ValidateSet('Play', 'Campaign', 'Valeggio', 'Battle', 'Grand', 'Editor', 'Verify')]
    [string]$Mode = 'Play',
    [string]$Godot = $env:GODOT_BIN
)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
if (-not $Godot) {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $folder = Join-Path $documents 'Tools/Godot'
    $candidate = Get-ChildItem $folder -Filter '*win64_console.exe' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($candidate) { $Godot = $candidate.FullName }
}
if (-not $Godot) {
    $candidate = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $Godot = $candidate.Source }
}
if (-not $Godot -or -not (Test-Path $Godot)) {
    throw 'Godot not found. Supply -Godot with the executable path, or set GODOT_BIN.'
}

function Invoke-Godot([string[]]$Arguments) {
    & $Godot @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE." }
}

if ($Mode -eq 'Editor') {
    Invoke-Godot @('--editor', '--path', $project)
} elseif ($Mode -eq 'Verify') {
    Invoke-Godot @('--headless', '--path', $project, '--import')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/simulation.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/weapons.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/regression.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/maps.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/bridge_movement.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/valeggio.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/terrain_relief.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/combat_motion.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/battle_orders.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/battle_ai.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/operations.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/polish.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/firing_audio.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/town_movement.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/battle_polish.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/performance_regression.gd')
    Invoke-Godot @('--headless', '--path', $project, '--script', 'res://tests/grand_landscape.gd')
    Invoke-Godot @('--path', $project, '--script', 'res://tests/grand_landscape.gd', '--', '--visual')
    Invoke-Godot @('--path', $project, '--script', 'res://tests/performance_regression.gd', '--', '--visual')
    Invoke-Godot @('--path', $project, '--script', 'res://tests/battle_polish.gd', '--', '--visual')
    Invoke-Godot @('--path', $project, '--script', 'res://tests/valeggio.gd')
    Invoke-Godot @('--path', $project, '--', '--verify')
} else {
    # Import first so a fresh checkout can run without opening the editor manually.
    Invoke-Godot @('--headless', '--path', $project, '--import')
    if ($Mode -eq 'Campaign') {
        Invoke-Godot @('--path', $project, '--', '--campaign-demo')
    } elseif ($Mode -eq 'Valeggio') {
        Invoke-Godot @('--path', $project, '--', '--valeggio-demo')
    } elseif ($Mode -eq 'Battle' -or $Mode -eq 'Grand') {
        $exercise = if ($Mode -eq 'Grand') { '--grand-battle-demo' } else { '--battle-demo' }
        Invoke-Godot @('--path', $project, '--', $exercise)
    } else {
        Invoke-Godot @('--path', $project)
    }
}
