# ============================
# Windows PowerShell CI/CD Script
# Node.js + Minikube Deployment (REVISED)
# ============================

# Ensure script stops immediately on a non-handled error
$ErrorActionPreference = "Stop"
#n
# -----------------------------------
# 1. Ensure Minikube is Running
# -----------------------------------
Write-Host "Checking Minikube status..." -ForegroundColor Cyan

# Check specifically for the 'Host: Running' status
$mkStatus = minikube status | Select-String "Host: Running"

if (-not $mkStatus) {
    Write-Host "Starting Minikube (this may take a moment)..." -ForegroundColor Yellow
    
    # Start Minikube, forcing the script to stop if start fails
    try {
        minikube start --driver=docker -ErrorAction Stop
    } catch {
        Write-Host "FATAL ERROR: Minikube failed to start or initialization error occurred." -ForegroundColor Red
        exit 1
    }
    Write-Host "Minikube started successfully." -ForegroundColor Green
} else {
    Write-Host "Minikube is already running." -ForegroundColor Green
}

# -----------------------------------
# 2. Set Docker Environment to Minikube
# -----------------------------------
Write-Host "Switching Docker to Minikube environment..." -ForegroundColor Cyan

# Invoke-Expression executes the environment variables (like DOCKER_HOST) provided by minikube
minikube docker-env | Invoke-Expression

# -----------------------------------
# 3. Build Docker Image
# -----------------------------------
$IMAGE_NAME = "class-btech:dev"
Write-Host "Building Docker image $IMAGE_NAME ..." -ForegroundColor Cyan

try {
    # -ErrorAction Stop ensures that if the build fails, the catch block is hit.
    docker build -t $IMAGE_NAME . -ErrorAction Stop
    Write-Host "Docker image built successfully." -ForegroundColor Green
} catch {
    Write-Host "FATAL ERROR: Failed to build Docker image! Check your Dockerfile." -ForegroundColor Red
    exit 1
}

# -----------------------------------
# 4. Update deployment.yaml Image
# -----------------------------------
Write-Host "Updating deployment.yaml with image $IMAGE_NAME ..." -ForegroundColor Cyan

$DeploymentFile = "deployment.yaml"

if (Test-Path $DeploymentFile) {
    (Get-Content $DeploymentFile) `
        -replace "image: .*", "image: $IMAGE_NAME" | `
        Set-Content $DeploymentFile
    Write-Host "$DeploymentFile updated." -ForegroundColor Green
} else {
    Write-Host "FATAL ERROR: $DeploymentFile not found!" -ForegroundColor Red
    exit 1
}

# -----------------------------------
# 5. Apply Kubernetes YAML Files
# -----------------------------------
Write-Host "Applying Kubernetes files..." -ForegroundColor Cyan

try {
    # Apply files, using -ErrorAction Stop for robustness
    kubectl apply -f deployment.yaml --validate=false -ErrorAction Stop
    kubectl apply -f service.yaml --validate=false -ErrorAction Stop
    Write-Host "Kubernetes files applied successfully." -ForegroundColor Green
} catch {
    Write-Host "FATAL ERROR: Failed to apply Kubernetes files! Check YAML syntax or kubectl connectivity." -ForegroundColor Red
    exit 1
}

# -----------------------------------
# 6. Restart Deployment (Force Pull)
# -----------------------------------
Write-Host "Restarting deployment to force a new image pull..." -ForegroundColor Cyan
kubectl rollout restart deployment/node-deployment
Start-Sleep -Seconds 2 # Short pause for kubectl to register

# -----------------------------------
# 7. Wait & Display Status
# -----------------------------------
Start-Sleep -Seconds 5 # Longer wait to allow rollout to begin

Write-Host "`n--- Deployment Status ---" -ForegroundColor Green
kubectl get pods -o wide --show-labels

Write-Host "`n--- Service Info ---" -ForegroundColor Green
kubectl get svc

# -----------------------------------
# 8. Success Message
# -----------------------------------
Write-Host "`n🎉 CI/CD Deployment completed successfully! Access your service via 'minikube service node-service-name'" -ForegroundColor Green -BackgroundColor Black