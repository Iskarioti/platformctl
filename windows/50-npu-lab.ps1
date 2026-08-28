# Native Windows exception for Intel AI Boost / OpenVINO NPU testing.
# This is NOT the normal application-development environment.

$ErrorActionPreference = "Stop"

Write-Host "Checking NPU..."
Get-PnpDevice | Where-Object {
    $_.FriendlyName -match "NPU|AI Boost|Neural"
} | Format-Table Status, Class, FriendlyName -AutoSize

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    winget install --id Python.Python.3.13 --exact --silent `
      --accept-package-agreements --accept-source-agreements
}

$Lab = Join-Path $env:USERPROFILE "AI-Labs\openvino-npu"
New-Item -ItemType Directory -Force -Path $Lab | Out-Null
Set-Location $Lab

py -3.13 -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --upgrade pip

& .\.venv\Scripts\python.exe -m pip install `
  nncf==2.18.0 `
  onnx==1.18.0 `
  optimum-intel==1.25.2 `
  transformers==5.0.0 `
  openvino==2026.3.0 `
  openvino-tokenizers==2026.3.0.0 `
  openvino-genai==2026.3.0.0

$Verify = @'
from openvino import Core

core = Core()
print("OpenVINO devices:")
for device in core.available_devices:
    print(f"  - {device}")

if "NPU" not in core.available_devices:
    raise SystemExit("NPU is not available to OpenVINO. Check the Intel NPU driver.")
print("NPU detected by OpenVINO.")
'@

Set-Content -Path .\verify_npu.py -Value $Verify -Encoding UTF8

& .\.venv\Scripts\python.exe .\verify_npu.py

Write-Host "NPU lab: $Lab"
