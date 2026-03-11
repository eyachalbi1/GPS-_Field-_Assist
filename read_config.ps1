$content = Get-Content 'c:\1.0\mobile\lib\utils\config.dart' -Raw
$idx = $content.IndexOf('firstWhere')
if ($idx -gt 0) {
    $content.Substring($idx, 200)
}

