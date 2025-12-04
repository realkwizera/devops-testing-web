# ============================
# Windows PowerShell CI/CD Script
# Node.js + Minikube Deployment
# ============================

$ErrorActionPreference = "Stop"

# -----------------------------------
# 1. Ensure Minikube is Running
# -----------------------------------
Write-Host "Checking Minikube status..." -ForegroundColor Cyan
$mkStatus = minikube status | Select-String "Running"

if (-not $mkStatus) {
    Write-Host "Starting Minikube..." -ForegroundColor Yellow
    minikube start --driver=docker
} else {
    Write-Host "Minikube is already running." -ForegroundColor Green
}

# -----------------------------------
# 2. Set Docker Environment to Minikube
# -----------------------------------
Write-Host "Switching Docker to Minikube environment..." -ForegroundColor Cyan
minikube docker-env | Invoke-Expression

# -----------------------------------
# 3. Build Docker Image
# -----------------------------------
$IMAGE_NAME = "btech:dev"
Write-Host "Building Docker image $IMAGE_NAME ..." -ForegroundColor Cyan

try {
    docker build -t $IMAGE_NAME .
} catch {
    Write-Host "ERROR: Failed to build Docker image!" -ForegroundColor Red
    exit 1
}

# -----------------------------------
# 4. Update deployment.yaml Image
# -----------------------------------
Write-Host "Updating deployment.yaml with image $IMAGE_NAME ..." -ForegroundColor Cyan

if (Test-Path "deployment.yaml") {
    (Get-Content deployment.yaml) `
        -replace "image: .*", "image: $IMAGE_NAME" |
        Set-Content deployment.yaml
} else {
    Write-Host "ERROR: deployment.yaml not found!" -ForegroundColor Red
    exit 1
}

# -----------------------------------
# 5. Apply Kubernetes YAML Files
# -----------------------------------
Write-Host "Applying Kubernetes files..." -ForegroundColor Cyan

try {
    kubectl apply -f deployment.yaml --validate=false
    kubectl apply -f service.yaml --validate=false
} catch {
    Write-Host "ERROR: Failed to apply Kubernetes files!" -ForegroundColor Red
    exit 1
}

# -----------------------------------
# 6. Restart Deployment (Optional)
# -----------------------------------
Write-Host "Restarting deployment..." -ForegroundColor Cyan
kubectl rollout restart deployment/node-deployment

# -----------------------------------
# 7. Wait & Display Status
# -----------------------------------
Start-Sleep -Seconds 3

Write-Host "Deployment status:" -ForegroundColor Green
kubectl get pods -o wide

Write-Host "`nService info:" -ForegroundColor Green
kubectl get svc

# -----------------------------------
# 8. Success Message
# -----------------------------------
Write-Host "`n🎉 CI/CD Deployment completed successfully!" -ForegroundColor Green -BackgroundColor Black