# Windows: captura en el host (contra el sitio local) y arma el video en WSL.
#
# `edge-tts`, `ffmpeg` y `jq` no están en un host Windows típico, pero sí en WSL
# Ubuntu. En vez de reescribir el motor, se lo llama del otro lado del puente.
# Ver reference/gotchas.md, "Windows".
#
#   .\make_videos.ps1 -Flow alta
#   $env:VOICE = "es-CO-SalomeNeural"; .\make_videos.ps1 -Flow alta

param(
    [Parameter(Mandatory = $true)][string]$Flow,
    [switch]$SoloArmar
)

$ErrorActionPreference = "Stop"
$EngineDir = $PSScriptRoot

# Busca e2e-video-doc.json hacia arriba desde el cwd.
$Dir = (Get-Location).Path
while ($Dir -and -not (Test-Path (Join-Path $Dir "e2e-video-doc.json"))) {
    $Dir = Split-Path $Dir -Parent
}
if (-not $Dir) { throw "No encontré e2e-video-doc.json desde $(Get-Location) hacia arriba." }
$Root = $Dir
$Config = Get-Content (Join-Path $Root "e2e-video-doc.json") -Raw | ConvertFrom-Json

if (-not $Config.flows.$Flow) {
    $definidos = ($Config.flows.PSObject.Properties.Name -join ", ")
    throw "El flujo '$Flow' no está en la config. Definidos: $definidos"
}

function Campo([string]$Clave) {
    $v = $Config.flows.$Flow.$Clave
    if (-not $v) { $v = $Config.defaults.$Clave }
    if (-not $v) { throw "Falta '$Clave' para el flujo '$Flow'" }
    return $v.Replace("{flow}", $Flow)
}

$Shots     = Join-Path $Root (Campo "screenshots")
$Narration = Join-Path $Root (Campo "narration")
$Output    = Join-Path $Root (Campo "output")
$Voice     = if ($env:VOICE) { $env:VOICE }
             elseif ($Config.flows.$Flow.voice) { $Config.flows.$Flow.voice }
             elseif ($Config.defaults.voice) { $Config.defaults.voice }
             else { "es-AR-ElenaNeural" }

if (-not (Test-Path $Narration)) { throw "No hay narración: $Narration" }

if (-not $SoloArmar) {
    Write-Host "> $Flow - capturando"
    Push-Location $Root
    try {
        $env:RUN_VIDEO_TESTS = "1"
        # Un solo flujo por corrida: varios specs de video a la vez pelean por el
        # estado compartido (flags de config, datos sembrados) y tardan el doble.
        $cmd = (Campo "capture").Replace("{flow}", $Flow)
        cmd /c $cmd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally { Pop-Location }
}

function Convert-ToWslPath([string]$WinPath) {
    # La conversion se hace aca y no con `wsl wslpath`: al pasar por PowerShell, wsl.exe se
    # come las barras invertidas y el argumento le llega como "C:UsersOmenDev..." -- tira
    # sin decir por que. Hacerlo local es determinista y saca una pieza movil del medio.
    $full = [System.IO.Path]::GetFullPath($WinPath)
    if ($full -notmatch '^[A-Za-z]:') {
        throw "no es una ruta de Windows con unidad: $WinPath"
    }
    $unidad = $full.Substring(0, 1).ToLower()
    # .Replace y no -replace: el segundo es regex y una barra invertida sola no compila.
    $resto = $full.Substring(2).Replace('\', '/')
    return "/mnt/$unidad$resto"
}

$wslShots     = Convert-ToWslPath $Shots
$wslNarration = Convert-ToWslPath $Narration
$wslOutput    = Convert-ToWslPath $Output
$wslScript    = Convert-ToWslPath (Join-Path $EngineDir "make_video.sh")

Write-Host "> $Flow - narrando y armando en WSL ($Voice)"
wsl bash -lc "VOICE='$Voice' NARRATION='$wslNarration' SCREENSHOTS='$wslShots' OUTPUT='$wslOutput' bash '$wslScript'"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "OK: $Output"
