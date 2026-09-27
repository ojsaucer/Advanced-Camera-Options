[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$files = @(
    'manifest.json', 'main.lua', 'geometry.lua', 'adapter_gen3.lua',
    'settings_help.lua', 'tilt_geometry.lua', 'tilt_render.lua',
    'void_backdrop.lua', 'compatibility.lua', 'mod.card', 'README.md', 'CHANGELOG.md',
    'docs\TECHNICAL.md', 'CONTRIBUTING.md'
)
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
if ($manifest.id -cnotmatch '^[a-z0-9_]+$' -or
    $manifest.version -cnotmatch '^\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?$') {
    throw 'Manifest ID or version cannot be used as a package filename.'
}
foreach ($name in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) {
        throw "Required package file is missing: $name"
    }
}
$dist = Join-Path $PSScriptRoot 'dist'
[System.IO.Directory]::CreateDirectory($dist) | Out-Null
$filename = '{0}-{1}.zip' -f $manifest.id, $manifest.version
$destination = Join-Path $dist $filename
$temporary = $destination + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
$stamp = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
try {
    $stream = [System.IO.File]::Open($temporary, 'CreateNew', 'ReadWrite', 'None')
    try {
        $zip = [System.IO.Compression.ZipArchive]::new($stream, 'Create', $true)
        try {
            foreach ($name in $files) {
                $entry = $zip.CreateEntry($name.Replace('\', '/'), 'Optimal')
                $entry.LastWriteTime = $stamp
                $inputStream = [System.IO.File]::OpenRead((Join-Path $PSScriptRoot $name))
                try {
                    $entryStream = $entry.Open()
                    try {
                        $inputStream.CopyTo($entryStream)
                    } finally {
                        $entryStream.Dispose()
                    }
                } finally {
                    $inputStream.Dispose()
                }
            }
        } finally {
            $zip.Dispose()
        }
    } finally {
        $stream.Dispose()
    }

    $zip = [System.IO.Compression.ZipFile]::OpenRead($temporary)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        if ($zip.Entries.Count -ne $files.Count) {
            throw 'Archive inventory does not match the package allowlist.'
        }
        foreach ($name in $files) {
            $entry = $zip.GetEntry($name.Replace('\', '/'))
            if ($null -eq $entry) { throw "Archive is missing $name" }
            $inputStream = [System.IO.File]::OpenRead((Join-Path $PSScriptRoot $name))
            try {
                $expected = [BitConverter]::ToString($sha.ComputeHash($inputStream))
            } finally {
                $inputStream.Dispose()
            }
            $entryStream = $entry.Open()
            try {
                $actual = [BitConverter]::ToString($sha.ComputeHash($entryStream))
            } finally {
                $entryStream.Dispose()
            }
            if ($actual -ne $expected) { throw "Archived contents differ from source: $name" }
        }
    } finally {
        $sha.Dispose()
        $zip.Dispose()
    }
    Move-Item -LiteralPath $temporary -Destination $destination -Force
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText($destination + '.sha256',
        "$hash  $filename`n", [System.Text.UTF8Encoding]::new($false))
    Write-Output "Built and verified $destination ($($files.Count) files)"
    Write-Output "SHA256 $hash"
} finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
}
