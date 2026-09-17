# Windows: capture on the host (against the local site), then assemble the video with one of
# two engines:
#
#   dotnet  engine\dotnet, make_video.sh in C#. Needs the .NET 10 SDK (Visual Studio 2026 has
#           it) and nothing else: the voice comes from the same service edge-tts uses, and
#           ffmpeg is fetched on first use.
#   wsl     engine\make_video.sh, across the bridge into WSL, where edge-tts, ffmpeg and jq
#           live.
#
# Everything below resolves voice, rate, language and titleAssets once, and both engines get
# the same values through the same environment variables. See reference/gotchas.md, "Windows".
#
#   .\make_videos.ps1 -Flow checkout
#   .\make_videos.ps1 -Flow checkout -Lang en
#   .\make_videos.ps1 -Flow checkout -CaptureOnly   # screenshots, no narration yet
#   .\make_videos.ps1 -Flow checkout -AssembleOnly  # from the screenshots already there
#   .\make_videos.ps1 -Flow checkout -Engine wsl    # force one engine (default: auto)
#   $env:VOICE = "en-GB-SoniaNeural"; .\make_videos.ps1 -Flow checkout

param(
    [Parameter(Mandatory = $true)][string]$Flow,
    [string]$Lang,
    [switch]$AssembleOnly,
    [switch]$CaptureOnly,
    # auto: dotnet when a .NET 10+ SDK is installed, wsl otherwise.
    [ValidateSet("auto", "dotnet", "wsl")][string]$Engine = "auto"
)

if ($AssembleOnly -and $CaptureOnly) { throw "-AssembleOnly and -CaptureOnly are opposites; pick one." }

$ErrorActionPreference = "Stop"
$EngineDir = $PSScriptRoot

# Search for e2e-video-doc.json upward from the cwd.
$Dir = (Get-Location).Path
while ($Dir -and -not (Test-Path (Join-Path $Dir "e2e-video-doc.json"))) {
    $Dir = Split-Path $Dir -Parent
}
if (-not $Dir) { throw "No e2e-video-doc.json found from $(Get-Location) upward." }
$Root = $Dir
$Config = Get-Content (Join-Path $Root "e2e-video-doc.json") -Raw | ConvertFrom-Json

if (-not $Config.flows.$Flow) {
    $defined = ($Config.flows.PSObject.Properties.Name -join ", ")
    throw "Flow '$Flow' is not in the config. Defined: $defined"
}

# Languages are optional. Without them, {lang} and {lang_suffix} resolve to empty.
$Languages = $Config.languages
$HasLangs = $Languages -and $Languages.PSObject.Properties.Name.Count -gt 0
if ($HasLangs) {
    # PSObject.Properties preserves document order, unlike a sorted key list.
    $LangCode = if ($Lang) { $Lang } else { $Languages.PSObject.Properties.Name[0] }
    if (-not $Languages.$LangCode) {
        $defined = ($Languages.PSObject.Properties.Name -join ", ")
        throw "Language '$LangCode' is not in the config. Defined: $defined"
    }
    $LangSuffix = if ($null -ne $Languages.$LangCode.suffix) { $Languages.$LangCode.suffix } else { "" }
}
else {
    if ($Lang) { throw "This config declares no languages, but '$Lang' was passed." }
    $LangCode = ""
    $LangSuffix = ""
}

function Field([string]$Key) {
    $v = $Config.flows.$Flow.$Key
    if (-not $v) { $v = $Config.defaults.$Key }
    if (-not $v) { throw "Missing '$Key' for flow '$Flow'" }
    return $v.Replace("{flow}", $Flow).Replace("{lang_suffix}", $LangSuffix).Replace("{lang}", $LangCode)
}

$Shots     = Join-Path $Root (Field "screenshots")
$Narration = Join-Path $Root (Field "narration")
$Output    = Join-Path $Root (Field "output")
$Voice     = if ($env:VOICE) { $env:VOICE }
             elseif ($HasLangs -and $Languages.$LangCode.voice) { $Languages.$LangCode.voice }
             elseif ($Config.flows.$Flow.voice) { $Config.flows.$Flow.voice }
             elseif ($Config.defaults.voice) { $Config.defaults.voice }
             else { "en-US-JennyNeural" }
$Rate      = if ($env:RATE) { $env:RATE }
             elseif ($HasLangs -and $Languages.$LangCode.rate) { $Languages.$LangCode.rate }
             elseif ($Config.flows.$Flow.rate) { $Config.flows.$Flow.rate }
             elseif ($Config.defaults.rate) { $Config.defaults.rate }
             else { "+0%" }
$Label     = if ($LangCode) { "$Flow ($LangCode)" } else { $Flow }

if (-not $AssembleOnly) {
    Write-Host "> $Label - capturing"
    Push-Location $Root
    try {
        $env:RUN_VIDEO_TESTS = "1"
        $env:E2E_VIDEO_DOC_ENGINE = $EngineDir
        $env:SCREENSHOTS = $Shots
        # One flow per run: several video specs at once fight over shared state
        # (config flags, seeded data) and take twice as long.
        cmd /c (Field "capture")
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally { Pop-Location }
}

# Static title/closing cards, declared once and copied in rather than the capture step
# doing its own copy. Named "00_<name>.png" so a narration entry naming it finds it
# regardless of how many real captures precede or follow it — see reference/narration.md.
$TitleAssets = $Config.flows.$Flow.titleAssets
if (-not $TitleAssets) { $TitleAssets = $Config.defaults.titleAssets }
if ($TitleAssets) {
    if (-not (Test-Path $Shots)) { New-Item -ItemType Directory -Path $Shots | Out-Null }
    foreach ($prop in $TitleAssets.PSObject.Properties) {
        $assetName = $prop.Name
        $assetSrc = Join-Path $Root ($prop.Value.Replace("{flow}", $Flow).Replace("{lang_suffix}", $LangSuffix).Replace("{lang}", $LangCode))
        if (-not (Test-Path $assetSrc)) { throw "titleAssets.$assetName`: no such file: $assetSrc" }
        Copy-Item $assetSrc (Join-Path $Shots "00_$assetName.png") -Force
    }
}

function Convert-ToWslPath([string]$WinPath) {
    # Converted here rather than with `wsl wslpath`: going through PowerShell, wsl.exe
    # eats the backslashes and the argument arrives as "C:UsersDev..." -- it fails
    # without saying why. Doing it locally is deterministic and removes a moving part.
    $full = [System.IO.Path]::GetFullPath($WinPath)
    if ($full -notmatch '^[A-Za-z]:') {
        throw "not a Windows path with a drive letter: $WinPath"
    }
    $drive = $full.Substring(0, 1).ToLower()
    # .Replace and not -replace: the latter is regex, and a lone backslash does not compile.
    $rest = $full.Substring(2).Replace('\', '/')
    return "/mnt/$drive$rest"
}

$wslShots     = Convert-ToWslPath $Shots
$wslNarration = Convert-ToWslPath $Narration
$wslOutput    = Convert-ToWslPath $Output
$wslScript    = Convert-ToWslPath (Join-Path $EngineDir "make_video.sh")

if ($CaptureOnly) {
    Write-Host ""
    Write-Host "OK: screenshots in $Shots"
    Write-Host "Look at them before writing the narration - fixing the walkthrough is far"
    Write-Host "cheaper before the audio exists. Then rerun without -CaptureOnly."
    exit 0
}

# Checked here rather than up front: the narration is what assembling needs, and step 5
# of the skill is to capture and look at the PNGs before writing it.
if (-not (Test-Path $Narration)) {
    throw "No narration file: $Narration`nCapture first with -CaptureOnly, then write it."
}

if ($Engine -eq "auto") {
    # A .NET 10 SDK is the whole requirement of the dotnet engine. Without it, WSL is the
    # engine this script has always used.
    $sdks = @()
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        $sdks = @(& dotnet --list-sdks 2>$null | ForEach-Object { if ($_ -match '^(\d+)\.') { [int]$Matches[1] } })
    }
    $Engine = if (($sdks | Where-Object { $_ -ge 10 }).Count -gt 0) { "dotnet" } else { "wsl" }
}

if ($Engine -eq "dotnet") {
    Write-Host "> $Label - narrating and assembling with the .NET engine ($Voice)"
    # The same environment make_video.sh reads. Set for the child and put back afterwards,
    # so a run from an interactive PowerShell does not leave them behind in the session.
    $vars = @{ VOICE = $Voice; RATE = $Rate; NARRATION = $Narration; SCREENSHOTS = $Shots; OUTPUT = $Output }
    $saved = @{}
    foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    try {
        # `dotnet run` builds the engine the first time and reuses the build after that.
        & dotnet run --project (Join-Path $EngineDir "dotnet\E2EVideoDoc.Engine.csproj") -c Release -v q
        $code = $LASTEXITCODE
    }
    finally {
        foreach ($k in $vars.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    if ($code -ne 0) { exit $code }
}
else {
    Write-Host "> $Label - narrating and assembling in WSL ($Voice)"
    # `tr -d '\r'`: a clone made with core.autocrlf=true - the Windows default - gives the
    # engine's .sh files CRLF endings, and bash dies on its own shebang with
    # "\r: command not found". .gitattributes fixes this at the source for fresh clones;
    # this rescues the ones that already exist, and is a no-op once they are LF.
    wsl bash -lc "VOICE='$Voice' RATE='$Rate' NARRATION='$wslNarration' SCREENSHOTS='$wslShots' OUTPUT='$wslOutput' bash <(tr -d '\r' < '$wslScript')"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host ""
Write-Host "OK: $Output"
