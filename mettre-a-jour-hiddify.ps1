# Met PandaVPN à jour avec la dernière version STABLE de Hiddify (jamais les bêtas),
# en rejouant les modifications PandaVPN par-dessus, puis recompile et installe sur le téléphone.
#
# Usage : clic droit > Exécuter avec PowerShell, ou :
#   powershell -ExecutionPolicy Bypass -File mettre-a-jour-hiddify.ps1 [-Version v5.9.20] [-SansInstaller]
#
# En cas de conflit (Hiddify a changé une ligne que PandaVPN modifie aussi), le script s'arrête
# sans rien casser : la branche perso-chine reste telle quelle (git rebase --abort).

param([string]$Version = '', [switch]$SansInstaller)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# le script vit à la racine du dépôt (à côté de pubspec.yaml)
$app = if (Test-Path (Join-Path $here 'pubspec.yaml')) { $here } else { Join-Path $here 'hiddify-app' }
$baseFile = Join-Path $app '.perso-base'   # version (ou commit) de Hiddify sur laquelle PandaVPN est posé

$env:TMP = 'C:\dev\tmp'; $env:TEMP = 'C:\dev\tmp'
$env:GRADLE_OPTS = '-Djdk.net.unixdomain.tmpdir=C:\dev\tmp -Djava.io.tmpdir=C:\dev\tmp'
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:\dev\tmp'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = "$env:USERPROFILE\scoop\apps\openjdk21\current" }
$env:PATH = "C:\dev\flutter\bin;$env:JAVA_HOME\bin;$env:PATH"
function Etape($m) { Write-Host "`n== $m" -ForegroundColor Cyan }

Set-Location $app
if (git status --porcelain --untracked-files=no) { throw "Des modifications ne sont pas commitées dans hiddify-app : commite-les d'abord." }
$old = (Get-Content $baseFile -ErrorAction Stop).Trim()

Etape "Recherche de la dernière version stable de Hiddify"
if (-not $Version) {
    $tags = git -c http.version=HTTP/1.1 ls-remote --tags --refs origin 'v*' | ForEach-Object { ($_ -split 'refs/tags/')[1] }
    # stables seulement : vX.Y.Z sans -beta, -dev, -rc...
    $stable = $tags | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' } | Sort-Object { [version]$_.TrimStart('v') }
    $Version = $stable | Select-Object -Last 1
}
$current = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
Write-Host "Dernière stable : $Version - PandaVPN : $current (base $old)"
if ([version]$Version.TrimStart('v') -le [version]$current) { Write-Host 'Déjà à jour : aucune version stable plus récente.'; exit 0 }

Etape "Téléchargement de $Version"
git -c http.version=HTTP/1.1 fetch --depth=1 origin tag $Version
$oldCommit = git rev-list -n 1 $old 2>$null
if (-not $oldCommit) { git -c http.version=HTTP/1.1 fetch --depth=1 origin tag $old; $oldCommit = git rev-list -n 1 $old }

Etape "Rejoue les modifications PandaVPN par-dessus $Version"
$backup = "sauvegarde-avant-$Version"
git branch -f $backup perso-chine
git rebase --onto $Version $oldCommit perso-chine
if ($LASTEXITCODE -ne 0) {
    git rebase --abort
    throw "Conflit avec $Version : rien n'a changé (sauvegarde : branche $backup). Demande à Claude de faire la fusion."
}
Set-Content $baseFile $Version
git add .perso-base
git -c user.name=PandaVPN -c user.email=pandavpn@localhost commit -q -m "chore: base Hiddify $Version"

Etape "Moteur VPN (hiddify-core)"
$core = (Select-String -Path dependencies.properties -Pattern '^core.version=(.+)$').Matches[0].Groups[1].Value
$stamp = Join-Path $env:TEMP ".pandavpn-core-$core"
if (-not (Test-Path $stamp)) {
    New-Item -ItemType Directory -Force android\app\libs | Out-Null
    curl.exe -fL --retry 5 --retry-all-errors --http1.1 -o "$env:TEMP\core-android.tar.gz" "https://github.com/hiddify/hiddify-core/releases/download/v$core/hiddify-lib-android.tar.gz"
    tar xzf "$env:TEMP\core-android.tar.gz" -C android\app\libs
    New-Item -ItemType File -Force $stamp | Out-Null
}

Etape "Préparation (paquets, code généré, traductions)"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run slang

Etape "Compilation"
flutter build apk --release --target lib/main_prod.dart --target-platform android-arm64
$apk = Join-Path $app 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
Copy-Item $apk "$env:USERPROFILE\Downloads\PandaVPN-arm64.apk" -Force
Write-Host "APK : $env:USERPROFILE\Downloads\PandaVPN-arm64.apk"

if (-not $SansInstaller) {
    $d = (adb devices) -match "`tdevice$" | Select-Object -First 1
    if ($d) { adb -s ($d -split "`t")[0] install -r $apk } else { Write-Host 'Téléphone non branché : installe l''APK à la main.' }
}
Write-Host "`nPandaVPN est maintenant basé sur Hiddify $Version." -ForegroundColor Green
