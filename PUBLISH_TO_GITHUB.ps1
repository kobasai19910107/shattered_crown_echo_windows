$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$repo = 'https://github.com/kobasai19910107/shattered_crown_echo.git'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'Git for Windows が必要です。https://git-scm.com/downloads/win' -ForegroundColor Red
    exit 1
}
# Prevent accidentally sharing a Windows username or populated EOS credentials.
$bad = @()
$patterns = @(
    '(?i)[A-Z]:[\\/]Users[\\/][^\\/\s"'']+',
    '(?i)-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----',
    '(?i)(?:client_secret|encryption_key|password|access_token|api_key)\s*=\s*["''](?!["''])[^{"'']+["'']'
)
Get-ChildItem -Path . -Recurse -File -Include *.gd,*.json,*.cfg,*.md,*.yml,*.godot,*.tscn,*.ps1 | ForEach-Object {
    $file = $_
    if ($file.FullName -match '[\\/]\.git[\\/]') { return }
    $s = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    foreach ($re in $patterns) {
        if ($s -match $re) { $bad += $file.FullName; break }
    }
}
if ($bad.Count -gt 0) {
    Write-Host '公開前検査NG。以下のファイルを見直してください。' -ForegroundColor Red
    $bad | Sort-Object -Unique | ForEach-Object { Write-Host $_ }
    exit 1
}
Write-Host '公開前チェック OK'
if (-not (Test-Path .git)) { git init; if ($LASTEXITCODE -ne 0) { exit 1 } }
git config user.name 'kobasai19910107'
git config user.email '339870397+kobasai19910107@users.noreply.github.com'
git remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { git remote add origin $repo }
else {
    $found = (git remote get-url origin).Trim()
    if ($found -ne $repo) { Write-Host ('異なるリモート先のため中止: ' + $found); exit 1 }
}
$remoteRef = git ls-remote --heads origin main
if ($LASTEXITCODE -ne 0) { Write-Host 'GitHubへの接続・認証に失敗しました'; exit 1 }
if ($remoteRef) { Write-Host 'GitHubのmainブランチにはすでにファイルがあります。上書き防止のため自動公開を中止します。'; exit 1 }
git add .
if ($LASTEXITCODE -ne 0) { exit 1 }
git commit -m 'Add privacy-checked shattered_crown_echo Web migration candidate'
if ($LASTEXITCODE -ne 0) { exit 1 }
git branch -M main
if ($LASTEXITCODE -ne 0) { exit 1 }
git push -u origin main
if ($LASTEXITCODE -ne 0) { exit 1 }
Write-Host 'GitHubへの登録が完了しました。' -ForegroundColor Green
