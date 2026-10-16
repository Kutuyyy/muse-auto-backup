<#
.SYNOPSIS
  Cek artifact GitHub Actions & jalankan ulang (rerun) workflow yang berhenti/gagal.
.DESCRIPTION
  Butuh GitHub token (classic PAT, scope 'repo').
  Cara isi token (pilih salah satu):
    1) .\gh-actions-check.ps1 -Token "ghp_xxxx..."   (tidak disarankan, token tercatat di history)
    2) $env:GITHUB_TOKEN = "ghp_xxxx..." ; .\gh-actions-check.ps1 ...   (disarankan)
.EXAMPLE
  # Lihat 15 run terakhir + statusnya
  .\gh-actions-check.ps1 -Repo "cloudflare-dimzhub-my-id" -Action runs
.EXAMPLE
  # Cek artifact di satu run: ada isi / kosong / expired
  .\gh-actions-check.ps1 -Repo "cloudflare-dimzhub-my-id" -Action artifacts -RunId 123456789
.EXAMPLE
  # Download satu artifact jadi zip
  .\gh-actions-check.ps1 -Repo "cloudflare-dimzhub-my-id" -Action download -ArtifactId 987654 -OutFile "hasil.zip"
.EXAMPLE
  # Jalankan ulang job yang gagal/berhenti di satu run
  .\gh-actions-check.ps1 -Repo "cloudflare-dimzhub-my-id" -Action rerun -RunId 123456789
#>
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Owner = "Kutuyyy",
  [ValidateSet("runs", "artifacts", "rerun", "download")][string]$Action = "runs",
  [long]$RunId = 0,
  [long]$ArtifactId = 0,
  [string]$OutFile = "",
  [string]$Token = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"

if (-not $Token) {
  Write-Host "Token kosong." -ForegroundColor Red
  Write-Host 'Isi dengan: $env:GITHUB_TOKEN = "ghp_xxxx..." lalu jalankan lagi.'
  exit 1
}

$Headers = @{
  Authorization        = "Bearer $Token"
  Accept               = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}
$Base = "https://api.github.com/repos/$Owner/$Repo"

function Invoke-GhApi($Method, $Url, $Body = $null) {
  try {
    if ($Body) {
      return Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers `
        -Body ($Body | ConvertTo-Json -Depth 5) -ContentType "application/json"
    }
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers
  } catch {
    $msg = $_.Exception.Message
    if ($msg -match "401") { Write-Host "401: token salah / kedaluwarsa." -ForegroundColor Red }
    elseif ($msg -match "404") { Write-Host "404: repo/run/artifact tidak ditemukan (cek nama repo & ID)." -ForegroundColor Red }
    elseif ($msg -match "403") { Write-Host "403: token kurang scope 'repo'." -ForegroundColor Red }
    else { Write-Host "Error: $msg" -ForegroundColor Red }
    exit 1
  }
}

function Show-Runs {
  $r = Invoke-GhApi "GET" "$Base/actions/runs?per_page=15"
  if ($r.total_count -eq 0) { Write-Host "Belum ada workflow run di $Owner/$Repo."; return }
  $r.workflow_runs | ForEach-Object {
    $kesimpulan = $_.conclusion
    if (-not $kesimpulan) { $kesimpulan = $_.status }  # masih jalan: queued/in_progress
    [pscustomobject]@{
      RunId     = $_.id
      Workflow  = $_.name
      Status    = $kesimpulan
      Branch    = $_.head_branch
      Waktu     = ([datetime]$_.created_at).ToLocalTime().ToString("dd-MM HH:mm")
      Url       = $_.html_url
    }
  } | Format-Table -AutoSize
}

function Show-Artifacts {
  if ($RunId -eq 0) { Write-Host "Butuh -RunId. Lihat dulu via -Action runs." -ForegroundColor Yellow; exit 1 }
  $a = Invoke-GhApi "GET" "$Base/actions/runs/$RunId/artifacts"
  if ($a.total_count -eq 0) { Write-Host "Run $RunId tidak punya artifact."; return }
  $a.artifacts | ForEach-Object {
    $ket = if ($_.expired) { "EXPIRED (dihapus)" } elseif ($_.size_in_bytes -eq 0) { "KOSONG" } else { "ADA ISI" }
    [pscustomobject]@{
      ArtifactId = $_.id
      Nama       = $_.name
      Ukuran_KB  = [math]::Round($_.size_in_bytes / 1KB, 1)
      Kondisi    = $ket
      Dibuat     = ([datetime]$_.created_at).ToLocalTime().ToString("dd-MM HH:mm")
    }
  } | Format-Table -AutoSize
  Write-Host "Download: .\gh-actions-check.ps1 -Repo `"$Repo`" -Action download -ArtifactId <ID>" -ForegroundColor DarkGray
}

function Start-Rerun {
  if ($RunId -eq 0) { Write-Host "Butuh -RunId. Lihat dulu via -Action runs." -ForegroundColor Yellow; exit 1 }
  Invoke-GhApi "POST" "$Base/actions/runs/$RunId/rerun-failed-jobs" | Out-Null
  Write-Host "OK: rerun dikirim untuk run $RunId (job yang gagal/berhenti akan jalan lagi)." -ForegroundColor Green
  Write-Host "Pantau di tab Actions repo tersebut."
}

function Save-Artifact {
  if ($ArtifactId -eq 0) { Write-Host "Butuh -ArtifactId. Lihat dulu via -Action artifacts -RunId <ID>." -ForegroundColor Yellow; exit 1 }
  if (-not $OutFile) { $OutFile = "artifact-$ArtifactId.zip" }
  try {
    Invoke-WebRequest -Uri "$Base/actions/artifacts/$ArtifactId/zip" -Headers $Headers -OutFile $OutFile
  } catch {
    Write-Host "Gagal download: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
  $kb = [math]::Round((Get-Item $OutFile).Length / 1KB, 1)
  Write-Host "Tersimpan: $OutFile ($kb KB)" -ForegroundColor Green
}

switch ($Action) {
  "runs"      { Show-Runs }
  "artifacts" { Show-Artifacts }
  "rerun"     { Start-Rerun }
  "download"  { Save-Artifact }
}
