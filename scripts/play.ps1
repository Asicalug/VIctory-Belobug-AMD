# Starts the title with the settings this fork is played with (README.md, "How to run it").
#   scripts\play.ps1 -Exe <path of your own copy's executable>
# -Safe         without the newer, faster ways (the first thing to try when something is wrong)
# -RayTracing   the title's own ray-traced indirect light: lit interiors, about a third slower
# -Fsr4K        PC FidelityFX at 3840x2160 (quality, balanced or performance): FSR 4.1.2 where AMD's SDK offers it for the card, FSR 3.1 otherwise
# -Rx9070       RX 9070 XT: native 1440p, ray tracing, memory limits, shader workarounds
# -Performance  renderer ports and 30 fps pacing
# -Console      series-x (default) or series-s (1080p, less work)
# -Monitor      one-based display for the initial title window (default: primary)
# -Build        target\diag (the default, the build all measurements are of) or target\release
#               Light DRED is requested by default for diag and requires --features diagnostics.
# -BenchmarkSeconds
#               stop a benchmark after this many seconds, including loading time
# -More         other settings: -More @{VICTORY_PANEL='1'}
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [Parameter(Mandatory)][string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [ValidateSet('quality', 'balanced', 'performance')][string]$Fsr4K,
    [switch]$Rx9070,
    [switch]$Performance,
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    [ValidateRange(1, 86400)][int]$BenchmarkSeconds,
    [ValidateSet('series-x', 'series-s')][string]$Console = 'series-x',
    [ValidateRange(1, 16)][int]$Monitor,
    [string]$Keys,
    [hashtable]$More = @{}
)
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'; VICTORY_RELAY = '2'; VICTORY_WIDE_BACK = '1'; VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'; VICTORY_INDIRECT_WINDOW = '1'; VICTORY_RELAY_COPY = '1'; VICTORY_CARD_STEPS = '2'
    VICTORY_INDIRECT_BATCH = '2'; VICTORY_MAP_THREADS = '1'; VICTORY_TITLE_PRIORITIES = '0'; VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'; VICTORY_AMBIENT = '0.8'
}
if ($Build -eq 'diag') { $settings.VICTORY_D3D12_DRED = 'light' }
if ($Safe) {
    $settings.VICTORY_UNDER_WIDE = '0'; $settings.VICTORY_LAND_ECHO = '0'
} else {
    $settings.VICTORY_THIN = '1'; $settings.VICTORY_JOIN_PARTS = '8'; $settings.VICTORY_UPLOAD_AHEAD = '1'
}
if ($RayTracing) { $settings.VICTORY_BVH_BUILDER = '1' }
if ($Rx9070) {
    # AMD driver 32.0.32029.2010 crashes in amdxc64.dll on translated shaders.
    # Mask 59 turns off REUSE (bit 4), fixing the three startup compute shaders.
    # CSComputeSkinningTreeAnimVelocity (f168...) crashes with every optimization
    # mask, so leave its pipeline out. This can affect skinned animation velocity.
    # Record late pipelines too, so `victory warm` can test them separately.
    if (-not $PSBoundParameters.ContainsKey('Console')) { $Console = 'series-x' }
    $settings.VICTORY_D3D12_ADAPTER = 'Radeon RX 9070'
    $settings.VICTORY_SHADER_OPT = '59'
    $settings.VICTORY_SKIP_PIPELINES = 'f16876929fa64f9f'
    $settings.VICTORY_PIPELINE_BOOK = '1'
    # Native 2560x1440, not a lower internal image upscaled to 1440p.
    # The title's own upscaler also avoids shipping FSR4's fixed 1080p tables.
    $settings.VICTORY_OUTPUT = '2560x1440'
    $settings.VICTORY_WINDOW_MAX = '2560x1440'
    $settings.VICTORY_UPSCALER = '6'
    $settings.VICTORY_RENDER_SCALE = '1.0'
    $settings.VICTORY_BVH_BUILDER = '1'
    # Acceptance requires the title's largest mips, including under VRAM pressure.
    $settings.VICTORY_TEXTURE_MAX = '0'
    $settings.VICTORY_PIPELINE_WORKERS = '4'
    $settings.VICTORY_RESIDENCY = '1'
    # Asynchronous submission (stages 2 and 3): a submission is prepared, sent
    # and only waited for where a later one reads what it writes, so the
    # preparing of the next overlaps the card's own work. Additive stages cost
    # about 2.1 times less frame time in native heavy 3D at full quality
    # (14.3 against 6.4 fps at about 5,000 draws/frame) and do not raise the
    # combined footprint: with flights in the air the by-address arenas
    # (memory.rs) take a shared CPU/GPU buffer instead of title memory in
    # place, which moved 1.7 GB from the process's physical memory to the
    # card's own use in the measured runs. -More @{ VICTORY_LATE_WAIT = '0' }
    # restores the synchronous path with the arenas in place.
    $settings.VICTORY_LATE_WAIT = '3'
    # Keep host-side mirrors near their used ranges instead of 4 MiB cells.
    $settings.VICTORY_WINDOW_KB = '256'
    $settings.VICTORY_WINDOW_TAILS = '1'
    $settings.VICTORY_WINDOW_BUDGET_MB = '1024'
    $settings.VICTORY_RIPE_BLOCKS = '4'
}
if ($Performance) {
    $settings.VICTORY_PORT_CONSTANTS = '1'
    $settings.VICTORY_PORT_DESCRIPTORS = '1'
    $settings.VICTORY_PORT_CBV = '1'
    $settings.VICTORY_PORT_GUARD = '1'
    $settings.VICTORY_PORT_JOURNAL = '1'
    # A cap, not an output-size override: native resolution belongs to the preset.
    $settings.VICTORY_FRAME_INTERVAL_MS = '33.333'
}
if ($Fsr4K) { $settings.VICTORY_FSR_4K = $Fsr4K.ToLowerInvariant() }
if ($Monitor) { $settings.VICTORY_WINDOW_MONITOR = "$Monitor" }
if ($Keys) { $settings.VICTORY_KEYS = $Keys }
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }

$victory = Join-Path $PSScriptRoot "..\target\$Build\victory.exe"
if (-not (Test-Path $victory)) { Write-Host "No $victory. Build it first (README.md)."; exit 1 }
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; exit 1 }
# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR', 'VICTORY_FIDELITYFX_DIR'
$inherited = @(Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths })
foreach ($entry in $inherited) { Remove-Item "Env:$($entry.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$discarded = $inherited | Where-Object {
    $_.Name -notin $More.Keys -and -not $_.Value.Equals([Environment]::GetEnvironmentVariable($_.Name))
} | Sort-Object Name
if ($discarded) {
    Write-Host "Discarded inherited values for $($discarded.Name -join ', '). Use -More to pass them explicitly."
}
$Exe = (Resolve-Path $Exe).Path
Push-Location (Join-Path $PSScriptRoot '..')   # victory.toml is looked for here
$logDir = Join-Path $env:LOCALAPPDATA 'victory\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
# Windows PowerShell can retain Start-Process redirect handles until it exits.
# The combined log is complete; clear only our stale, already-copied fragments.
Get-ChildItem $logDir -Filter 'play-*.log.std*' -ErrorAction SilentlyContinue | Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddHours(-1)
} | Remove-Item -Force -ErrorAction SilentlyContinue
$log = Join-Path $logDir ("play-{0:yyyyMMdd-HHmmss}-{1}.log" -f (Get-Date), $PID)
Write-Host "Log: $log"
# Keep the evidence settings even if startup fails. Do not dump all of -More:
# callers may put unrelated secrets in their environment or wrapper settings.
$evidenceNames = @(
    'VICTORY_D3D12_ADAPTER', 'VICTORY_OUTPUT', 'VICTORY_WINDOW_MAX',
    'VICTORY_RENDER_SCALE', 'VICTORY_UPSCALER', 'VICTORY_FSR_4K',
    'VICTORY_BVH_BUILDER', 'VICTORY_TEXTURE_MAX', 'VICTORY_SHADER_OPT',
    'VICTORY_SKIP_PIPELINES', 'VICTORY_LATE_WAIT', 'VICTORY_CARD_BUFFERS_MIN_KB',
    'VICTORY_CARD_BUFFERS_MIN_MB', 'VICTORY_CARD_BUFFERS_MB',
    'VICTORY_FRAME_INTERVAL_MS', 'VICTORY_RESIDENCY', 'VICTORY_KEYS',
    'VICTORY_PORT_CONSTANTS', 'VICTORY_PORT_DESCRIPTORS', 'VICTORY_PORT_CBV',
    'VICTORY_PORT_GUARD', 'VICTORY_PORT_GUARD_PLAN', 'VICTORY_PORT_JOURNAL',
    'VICTORY_JOIN_PARTS', 'VICTORY_TITLE_PRIORITIES', 'VICTORY_MAP_THREADS',
    'VICTORY_LAND_THREADS', 'VICTORY_ASK_SPREAD', 'VICTORY_SYNC_FINE', 'VICTORY_AB',
    'VICTORY_MEMORY_BUDGET_MIB'
)
$header = @("Build: $Build", "Console: $Console", "BenchmarkSeconds: $BenchmarkSeconds")
$header += $evidenceNames | ForEach-Object {
    $value = if ($settings.ContainsKey($_)) { $settings[$_] } else { '<default>' }
    "Setting $_=$value"
}
Set-Content -Path $log -Value $header
try {
    if ($BenchmarkSeconds) {
        # Redirection avoids PowerShell wrapping native diagnostics at the
        # console width. The timeout includes loading and always reaps the test.
        $stdout = "$log.stdout"
        $stderr = "$log.stderr"
        $arguments = @('run', "`"$Exe`"", '--execute', '--console', $Console)
        $process = Start-Process -FilePath $victory -ArgumentList $arguments -PassThru `
            -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        Wait-Process -Id $process.Id -Timeout $BenchmarkSeconds -ErrorAction SilentlyContinue
        $process.Refresh()
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
            $status = -1
        } else {
            $status = $process.ExitCode
        }
        $process.Dispose()
        foreach ($output in @($stderr, $stdout)) {
            if (Test-Path $output) {
                # Explicit streams preserve the native bytes and close promptly;
                # Get-Content can retain its reader until pipeline cleanup.
                $reader = [IO.File]::Open($output, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                $writer = [IO.File]::Open($log, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
                try { $reader.CopyTo($writer) } finally { $reader.Dispose(); $writer.Dispose() }
                Remove-Item $output -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        & $victory run $Exe --execute --console $Console 2>&1 | Tee-Object -FilePath $log -Append
        $status = $LASTEXITCODE
    }
} finally {
    Pop-Location
}
Add-Content -Path $log -Value "VIctory exit code: $status"
Write-Host "VIctory exit code: $status"
exit $status
