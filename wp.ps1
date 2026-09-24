<#
  Atajos para Windows (PowerShell).

  Uso:
    .\wp.ps1 up        Levanta todo y abre el navegador cuando esté listo
    .\wp.ps1 down      Apaga los contenedores (conserva los datos)
    .\wp.ps1 reset     Borra TODO (base de datos y archivos) y reinstala desde cero
    .\wp.ps1 logs      Muestra el log de la autoconfiguración
    .\wp.ps1 status    Estado de los contenedores
    .\wp.ps1 cli ...   Ejecuta WP-CLI. Ej: .\wp.ps1 cli plugin list
    .\wp.ps1 backup    Exporta la base de datos a .\backups\

  Si PowerShell bloquea el script, ejecútalo así una vez:
    powershell -ExecutionPolicy Bypass -File .\wp.ps1 up
#>
param(
  [Parameter(Position = 0)][string]$Command = "help",
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Get-Port {
  $port = "8080"
  if (Test-Path ".env") {
    $line = Select-String -Path ".env" -Pattern '^\s*WP_PORT\s*=\s*(\d+)' | Select-Object -First 1
    if ($line) { $port = $line.Matches[0].Groups[1].Value }
  }
  return $port
}

function Assert-Docker {
  docker info *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker no está corriendo. Abre Docker Desktop y vuelve a intentar." -ForegroundColor Red
    exit 1
  }
}

function Start-Stack {
  Assert-Docker
  if (-not (Test-Path ".env")) { Copy-Item ".env.example" ".env"; Write-Host "Creado .env a partir de .env.example" }
  docker compose up -d
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "`nConfigurando WordPress (la primera vez tarda 1-3 minutos)...`n" -ForegroundColor Cyan
  docker compose logs -f wpcli
  $id = docker compose ps -a -q wpcli
  $code = docker inspect $id --format "{{.State.ExitCode}}"
  if ($code -eq "0") {
    Start-Process "http://localhost:$(Get-Port)"
  } else {
    Write-Host "La autoconfiguración terminó con error ($code). Revisa: .\wp.ps1 logs" -ForegroundColor Red
  }
}

switch ($Command) {
  "up"     { Start-Stack }
  "down"   { docker compose down }
  "reset"  {
    $ok = Read-Host "Esto borra la base de datos y los archivos de WordPress. Escribe 'si' para continuar"
    if ($ok -eq "si") { docker compose down -v; Start-Stack }
  }
  "logs"   { docker compose logs wpcli }
  "status" { docker compose ps -a }
  "cli"    { docker compose run --rm --no-deps --entrypoint php wpcli -d memory_limit=512M /usr/local/bin/wp --path=/var/www/html @Rest }
  "backup" {
    New-Item -ItemType Directory -Force -Path "backups" | Out-Null
    $file = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').sql"
    docker compose run --rm --no-deps --entrypoint sh -v "${PWD}/backups:/backups" wpcli -c "wp --path=/var/www/html db export /backups/$file"
    Write-Host "Guardado en backups\$file"
  }
  default  { Get-Content $PSCommandPath -TotalCount 15 | Select-Object -Skip 1 }
}
