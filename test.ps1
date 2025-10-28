# test.ps1
param(
    [string]$ServiceIP = "4.156.243.15"
)

Write-Host "=== 🧪 PRUEBA OFICIAL DEVOPS ===" -ForegroundColor Magenta
Write-Host ""

$API_KEY = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
$JWT = "jwt_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(Get-Random -Minimum 1000 -Maximum 9999)"

Write-Host "🔧 Configuración:" -ForegroundColor Yellow
Write-Host "   🌐 Service IP: $ServiceIP" -ForegroundColor White
Write-Host "   🔐 API Key: $API_KEY" -ForegroundColor White  
Write-Host "   🎫 JWT: $JWT" -ForegroundColor White
Write-Host ""

Write-Host "🚀 Ejecutando comando cURL oficial..." -ForegroundColor Green

$uri = "http://$ServiceIP/DevOps"
$headers = @{
    "X-Parse-REST-API-Key" = $API_KEY
    "X-JWT-KWY" = $JWT
    "Content-Type" = "application/json"
}
$body = '{"message": "This is a test", "to": "Juan Perez", "from": "Rita Asturia", "timeToLifeSec": 45}'

try {
    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body -TimeoutSec 30
    Write-Host "✅ ✅ ✅ PRUEBA EXITOSA ✅ ✅ ✅" -ForegroundColor Green
    Write-Host "📋 Response: $($response | ConvertTo-Json)" -ForegroundColor White
} catch {
    Write-Host "❌ ❌ ❌ PRUEBA FALLIDA ❌ ❌ ❌" -ForegroundColor Red
    Write-Host "📋 Error: $($_.Exception.Message)" -ForegroundColor White
    
    # Información detallada del error
    if ($_.Exception.Response) {
        Write-Host "🔍 Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $errorBody = $reader.ReadToEnd()
        Write-Host "📋 Error Body: $errorBody" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "🎯 Prueba completada!" -ForegroundColor Magenta