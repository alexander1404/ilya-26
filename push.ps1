<#
.SYNOPSIS
  Публикация страницы «Санкт-Сити // Илья 26» на GitHub Pages одной командой.

.DESCRIPTION
  Скрипт:
    1) проверяет наличие git и папки site;
    2) создаёт рабочую папку и копирует туда site\* (включая .nojekyll и .gitignore);
    3) напоминает добавить медиафайлы (img1..4, boomboks, track1..4, ilya-theme, neon-gamepad);
    4) git init -b main, add, commit;
    5) привязывает remote и делает push.
  Репозиторий на GitHub должен быть уже создан (пустой, Public):
      https://github.com/new  →  имя ilya-26  →  Public  →  Create repository
  После push включите Pages:
      https://github.com/alexander1404/ilya-26/settings/pages
      → Source: Deploy from a branch → main / (root) → Save

.EXAMPLE
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  .\push.ps1 -RepoUrl "https://github.com/alexander1404/ilya-26.git" -Target "C:\ilya-26"
#>
param(
  [string]$RepoUrl = "https://github.com/alexander1404/ilya-26.git",
  [string]$Target  = "C:\ilya-26",
  [string]$UserName = "alexander1404",
  [string]$UserEmail = "",
  [string]$Message  = "first upload"
)

# "Continue", а не "Stop": git пишет служебные сообщения в stderr, и при Stop
# PowerShell может превратить их в ошибку. Все критичные места проверяем сами.
$ErrorActionPreference = "Continue"
function Step($t) { Write-Host ""; Write-Host "==> $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "    [ok] $t" -ForegroundColor Green }
function Warn($t) { Write-Host "    [!]  $t" -ForegroundColor Yellow }
function Die($t)  { Write-Host ""; Write-Host "ОШИБКА: $t" -ForegroundColor Red; exit 1 }

# ── 0. проверки ───────────────────────────────────────────────────────────
Step "Проверяю окружение"
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) { Die "git не найден. Установите: https://git-scm.com/download/win и перезапустите VS Code" }
Ok (git --version)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$siteDir   = Join-Path $scriptDir "site"
if (-not (Test-Path $siteDir)) { Die "не найдена папка site рядом со скриптом ($siteDir)" }
Ok "папка site: $siteDir"

# ── 1. рабочая папка ──────────────────────────────────────────────────────
Step "Готовлю рабочую папку $Target"
if (-not (Test-Path $Target)) { New-Item -ItemType Directory -Path $Target | Out-Null; Ok "создана" }
else { Ok "уже существует" }
Copy-Item -Path (Join-Path $siteDir "*") -Destination $Target -Recurse -Force
Ok "файлы сайта скопированы (index.html, 404.html, README.md, .nojekyll, .gitignore)"

# ── 2. медиафайлы ─────────────────────────────────────────────────────────
Step "Проверяю медиафайлы"
$need = @(
  @{n="neon-gamepad"; t="welcome-экран"},
  @{n="joystick";     t="запасная картинка welcome"},
  @{n="bg-city";      t="фон первого экрана"},
  @{n="boomboks";     t="бумбокс"},
  @{n="ilya-theme";   t="фоновая тема"}
)
$exts = @(".jpg",".jpeg",".png",".webp",".mp3",".m4a",".wav",".ogg","")
$missing = @()
foreach ($f in $need) {
  $found = $false
  foreach ($e in $exts) { if (Test-Path (Join-Path $Target ($f.n + $e))) { $found = $true; break } }
  if (-not $found) { $missing += $f.n }
}
foreach ($i in 1..4) {
  $found = $false
  foreach ($e in $exts) { if (Test-Path (Join-Path $Target ("img$i$e"))) { $found = $true; break } }
  if (-not $found) { $missing += "img$i" }
}
foreach ($i in 1..4) {
  $found = $false
  foreach ($e in $exts) { if (Test-Path (Join-Path $Target ("track$i$e"))) { $found = $true; break } }
  if (-not $found) { $missing += "track$i" }
}
if ($missing.Count -gt 0) {
  Warn ("не хватает файлов: " + ($missing -join ", "))
  Warn "Скопируйте их в $Target и запустите скрипт заново (или продолжите — сайт будет работать с заглушками)."
  $ans = Read-Host "    Продолжить без них? (y/N)"
  if ($ans -ne "y") { Die "прервано пользователем" }
} else { Ok "все медиафайлы на месте" }

# сервер GitHub на Linux: IMG1.JPG и img1.jpg для него разные файлы.
# Проверяем только медиа (README.md и служебные файлы не трогаем).
$mediaExt = @(".jpg",".jpeg",".png",".webp",".mp3",".m4a",".wav",".ogg")
$upper = @(Get-ChildItem -Path $Target -File | Where-Object {
  $n = $_.Name
  ($mediaExt -contains [System.IO.Path]::GetExtension($n).ToLower()) -and ($n -cne $n.ToLower())
})
if ($upper.Count -gt 0) {
  Warn ("имена с заглавными буквами — сервер их не найдёт: " + (($upper | ForEach-Object { $_.Name }) -join ", "))
  Warn "Переименуйте в нижний регистр (git mv СТАРОЕ новое) и запустите скрипт заново."
}

# ── 3. размер файлов ──────────────────────────────────────────────────────
Step "Проверяю размеры"
$big = Get-ChildItem -Path $Target -File | Where-Object { $_.Length -gt 25MB }
foreach ($f in $big) { Warn ("файл больше 25 МБ (через браузер не загрузился бы, через git — ок): {0} — {1:N1} МБ" -f $f.Name, ($f.Length/1MB)) }
$hard = Get-ChildItem -Path $Target -File | Where-Object { $_.Length -gt 100MB }
if ($hard) { Die ("файлы больше 100 МБ GitHub не принимает: " + (($hard | ForEach-Object { $_.Name }) -join ", ") + " — сожмите их") }
$total = (Get-ChildItem -Path $Target -File | Measure-Object -Property Length -Sum).Sum
Ok ("общий вес папки: {0:N1} МБ" -f ($total/1MB))

# ── 4. git ────────────────────────────────────────────────────────────────
if ((Resolve-Path $Target).Path.Length -lt 4) { Die "подозрительно короткий путь: $Target" }
Set-Location $Target
Step "Инициализирую git"
if (Test-Path (Join-Path $Target ".git")) {
  Ok "репозиторий уже инициализирован"
} else {
  $v = (git --version) -replace "[^0-9\.]", ""
  git init -b main 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { git init 2>&1 | Out-Null; git branch -M main 2>&1 | Out-Null }
  Ok "git init (ветка main)"
}

if ($UserEmail -eq "") {
  $globalMail = (git config --global user.email 2>$null)
  if ($globalMail) { $UserEmail = $globalMail } else { $UserEmail = "$UserName@users.noreply.github.com" }
  Warn "email не указан, использую: $UserEmail (смените: git config user.email ""you@mail.ru"")"
}
git config user.name  $UserName
git config user.email $UserEmail
Ok "подпись коммитов: $UserName <$UserEmail>"

Step "Добавляю файлы и делаю коммит"
git add .
$staged = @(git diff --cached --name-only)
if ($staged.Count -eq 0) {
  Warn "нечего коммитить — файлы не изменились (это не ошибка, если вы уже всё отправили)"
} else {
  git commit -m $Message | Out-Null
  if ($LASTEXITCODE -ne 0) { Die "не удалось создать коммит — посмотрите вывод git выше" }
  Ok ("в коммите файлов: " + $staged.Count)
}

Step "Привязываю репозиторий GitHub"
$cur = git remote get-url origin 2>$null
if ($cur) {
  if ($cur -ne $RepoUrl) { git remote set-url origin $RepoUrl; Ok "remote обновлён: $RepoUrl" }
  else { Ok "remote уже привязан: $RepoUrl" }
} else {
  git remote add origin $RepoUrl
  Ok "remote добавлен: $RepoUrl"
}

Step "Отправляю на GitHub (может открыться окно входа в браузере)"
git push -u origin main
if ($LASTEXITCODE -ne 0) {
  Warn "push не прошёл. Возможные причины и лечение:"
  Warn "  - «rejected ... (fetch first)» — на GitHub уже есть коммиты (например, репозиторий"
  Warn "    создан с README). Выполните:  git pull origin main --rebase  →  git push"
  Warn "    (если история чужая и её не жалко:  git push -f origin main )"
  Warn "  - репозиторий не создан: https://github.com/new (имя ilya-26, Public, БЕЗ README)"
  Warn "  - «Authentication failed»: нужен токен https://github.com/settings/tokens (галочка repo)"
  Warn "  - «Repository not found»: проверьте URL — git remote -v"
  exit 1
}
Ok "файлы отправлены"

# ── 5. дальше ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host " Осталось два шага:" -ForegroundColor Magenta
Write-Host "  1. Включить Pages:" -ForegroundColor White
Write-Host "     https://github.com/alexander1404/ilya-26/settings/pages" -ForegroundColor Yellow
Write-Host "     Source: Deploy from a branch → Branch: main / (root) → Save" -ForegroundColor White
Write-Host ""
Write-Host "  2. Открыть сайт (через 1-3 минуты):" -ForegroundColor White
Write-Host "     https://alexander1404.github.io/ilya-26/" -ForegroundColor Yellow
Write-Host ""
Write-Host " Обновление сайта потом:  git add . ; git commit -m `"правка`" ; git push" -ForegroundColor DarkGray
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
