# dangbei_wol (ESP32-C3) flash script
# Usage:
#   .\flash.ps1
#   .\flash.ps1 -Port COM5
#   .\flash.ps1 -Port COM5 -Erase
#   .\flash.ps1 -ListPorts
#   .\flash.ps1 -Help

param(
    [string]$Port,
    [switch]$Erase,
    [switch]$ListPorts,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
# Support both layouts:
#   repo/tools/esp32-flash + repo/dist
#   release zip with bins next to flash.ps1
$DistCandidates = @(
    (Join-Path $PSScriptRoot 'dist'),
    (Join-Path $PSScriptRoot 'firmware'),
    $PSScriptRoot,
    (Join-Path (Split-Path $PSScriptRoot -Parent) 'dist'),
    (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'dist')
)
$Dist = $null
foreach ($cand in $DistCandidates) {
    if ((Test-Path (Join-Path $cand 'bootloader.bin')) -and
        (Test-Path (Join-Path $cand 'dangbei_wol.bin'))) {
        $Dist = $cand
        break
    }
}
if (-not $Dist) {
    $Dist = Join-Path $PSScriptRoot 'dist'
}
$Bootloader = Join-Path $Dist 'bootloader.bin'
$PartTable  = Join-Path $Dist 'partition-table.bin'
$App        = Join-Path $Dist 'dangbei_wol.bin'
$VenvDir    = Join-Path $PSScriptRoot '.esptool-venv'

function Show-Help {
    Write-Host "dangbei_wol ESP32-C3 flash tool"
    Write-Host "================================"
    Write-Host "Usage:"
    Write-Host "  .\flash.ps1 -ListPorts     List serial ports"
    Write-Host "  .\flash.ps1 -Port COM5     Flash to COM5"
    Write-Host "  .\flash.ps1                Auto-detect single port and flash"
    Write-Host "  .\flash.ps1 -Port COM5 -Erase   Erase whole flash, then write"
    Write-Host ""
    Write-Host "Addresses:"
    Write-Host "  0x0     bootloader.bin"
    Write-Host "  0x8000  partition-table.bin"
    Write-Host "  0x10000 dangbei_wol.bin"
    Write-Host ""
    Write-Host "Settings: chip=ESP32-C3  mode=DIO  freq=80MHz  size=4MB"
}

function Get-SerialPorts {
    try {
        return @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)
    } catch {
        return @()
    }
}

function Ensure-Esptool {
    $py = $null
    foreach ($cand in @('python', 'py', 'python3')) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if ($cmd) { $py = $cmd.Source; break }
    }
    if (-not $py) {
        throw "Python not found. Install Python 3 from https://www.python.org/downloads/"
    }

    $esptool = Join-Path $VenvDir 'Scripts\esptool.exe'
    if (-not (Test-Path $esptool)) {
        Write-Host "==> Creating venv and installing esptool ..."
        & $py -m venv $VenvDir
        if ($LASTEXITCODE -ne 0) { throw "venv create failed" }
        $venvPy = Join-Path $VenvDir 'Scripts\python.exe'
        & $venvPy -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed" }
        & $venvPy -m pip install "esptool>=4.7"
        if ($LASTEXITCODE -ne 0) { throw "esptool install failed" }
    }
    if (-not (Test-Path $esptool)) {
        throw "esptool missing after install: $esptool"
    }
    return $esptool
}

function Resolve-Port {
    param([string]$Requested)
    $ports = Get-SerialPorts
    if ($ListPorts) {
        Write-Host "Available serial ports:"
        if ($ports.Count -eq 0) {
            Write-Host "  (none) - plug in ESP32-C3; install CH341 driver if needed"
        } else {
            foreach ($p in $ports) { Write-Host "  $p" }
        }
    }
    if ($Requested) { return $Requested }
    if ($ports.Count -eq 0) {
        throw "No serial port found. Connect ESP32-C3 USB, check Device Manager, install CH341SER.EXE if required."
    }
    if ($ports.Count -gt 1) {
        Write-Host "Multiple ports: $($ports -join ', ')"
        Write-Host "Re-run with -Port COMx"
        throw "Multiple serial ports detected"
    }
    Write-Host "Auto-selected port: $($ports[0])"
    return $ports[0]
}

if ($Help) { Show-Help; exit 0 }

Write-Host "Script dir : $PSScriptRoot"
Write-Host "Firmware   : $Dist"

foreach ($f in @($Bootloader, $PartTable, $App)) {
    if (-not (Test-Path $f)) {
        throw "Missing firmware file: $f"
    }
    $item = Get-Item $f
    Write-Host ("  {0}  {1} bytes" -f $item.Name, $item.Length)
}

if ($ListPorts) {
    Resolve-Port -Requested 'LIST_ONLY' | Out-Null
    exit 0
}

$portName = Resolve-Port -Requested $Port
$esptool = Ensure-Esptool
Write-Host "esptool    : $esptool"
Write-Host "Port       : $portName"

$common = @(
    '--chip', 'esp32c3',
    '--port', $portName,
    '--baud', '460800',
    '--before', 'default_reset',
    '--after', 'hard_reset'
)

if ($Erase) {
    Write-Host ""
    Write-Host "==> Erasing flash ..."
    & $esptool @common erase-flash
    if ($LASTEXITCODE -ne 0) { throw "Erase failed (exit $LASTEXITCODE)" }
}

Write-Host ""
Write-Host "==> Flashing firmware ..."
$writeArgs = $common + @(
    'write-flash',
    '--flash-mode', 'dio',
    '--flash-freq', '80m',
    '--flash-size', '4MB',
    '0x0', $Bootloader,
    '0x8000', $PartTable,
    '0x10000', $App
)
& $esptool @writeArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Flash failed. Try:" -ForegroundColor Yellow
    Write-Host "  1) Hold BOOT, tap RST/EN, run again"
    Write-Host "  2) Use another USB cable/port (data cable required)"
    Write-Host "  3) Install ..\CH341SER.EXE serial driver"
    Write-Host "  4) .\flash.ps1 -Port $portName -Erase"
    throw "esptool exit $LASTEXITCODE"
}

Write-Host ""
Write-Host "==> Flash OK." -ForegroundColor Green
Write-Host "Device should hard-reset. Next steps:"
Write-Host "  1) Join SoftAP DangbeiWOL-XXXX"
Write-Host "  2) Open http://192.168.4.1/ and set 2.4GHz WiFi + token"
Write-Host "  3) Keep projector ON, set ESP32 IP/token in HA Dangbei options and SAVE"
Write-Host "  4) Power off projector, test remote.turn_on"
