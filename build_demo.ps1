# 构建 Windows Demo（第 12 周 Demo 包装）
# 用法：在 wasteland-echo 目录下执行  powershell -ExecutionPolicy Bypass -File build_demo.ps1
# 依赖：Godot 4.7.1 + Windows 导出模板（见下方提示）

$ErrorActionPreference = "Stop"

$godot = "E:\Codex\Godot 4.x\godot.exe"
$project = $PSScriptRoot
$outDir = Join-Path $project "exports"
$outExe = Join-Path $outDir "WastelandEcho.exe"

if (-not (Test-Path $godot)) {
    Write-Error "找不到 Godot：$godot"
    exit 1
}

# 检查导出模板是否已安装（缺模板时导出必然失败，提前给出提示）
$templatesDir = Join-Path $env:APPDATA "Godot\export_templates\4.7.1.stable"
if (-not (Test-Path $templatesDir)) {
    Write-Warning "未检测到 4.7.1 导出模板（$templatesDir）。"
    Write-Warning "请先安装：启动 Godot → 编辑器 → 管理导出模板 → 下载并安装 4.7.1 stable；或把模板目录放到上述路径。"
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Push-Location $project
try {
    & $godot --headless --path . --export-release "Windows Desktop" $outExe
    if ($LASTEXITCODE -ne 0) {
        throw "导出失败（exit=$LASTEXITCODE），请查看上方错误信息。"
    }
    Write-Host "导出成功：$outExe"
} catch {
    Write-Warning $_.Exception.Message
    Write-Warning "如果提示缺少导出模板，安装模板后重试本脚本即可；已安装则检查 preset 名称是否与 export_presets.cfg 一致。"
    exit 1
} finally {
    Pop-Location
}
