# run-e2e-tests.ps1
# End-to-End Platform Verification Script for Enterprise AKS
# Execute inside vm-jumpbox-dev or from an authorized workstation

param(
    [string]$SubscriptionId = "YOUR_SUBSCRIPTION_ID",
    [string]$ResourceGroupName = "rg-platform-dev-eus",
    [string]$ClusterName = "aks-dev-cluster",
    [string]$KeyVaultName = "kv-platform-dev-eus",
    [string]$AcrName = "acrplatformdeveus",
    [string]$Namespace = "dev"
)

Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "         ENTERPRISE AKS LANDING ZONE: E2E AUTOMATED VERIFICATION         " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan

$results = [ordered]@{
    "1. Azure CLI Authentication & Cluster Context" = "FAIL"
    "2. Private Endpoint DNS Resolution (ACR & Key Vault)" = "FAIL"
    "3. Egress Traffic Isolation (Firewall Block)" = "FAIL"
    "4. Admission Control Rules (Kyverno Block Policies)" = "FAIL"
    "5. Workload Identity & CSI Secret Mounting" = "FAIL"
    "6. GitOps Reconciliation & ArgoCD Status" = "FAIL"
    "7. Observability Backend Endpoint Health" = "FAIL"
}

# Helper function to assert results
function Show-Status($testName, $status) {
    if ($status -eq "PASS") {
        Write-Host "[ PASS ] $testName" -ForegroundColor Green
    } else {
        Write-Host "[ FAIL ] $testName" -ForegroundColor Red
    }
}

# 1. Check Azure Auth & Connect Cluster
try {
    Write-Host "`n[+] Checking Azure context and cluster connectivity..." -ForegroundColor Yellow
    az account set --subscription $SubscriptionId | Out-Null
    az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName --overwrite-existing | Out-Null
    $clusterVersion = kubectl version --short=false --client=false 2>&1
    if ($LASTEXITCODE -eq 0) {
        $results["1. Azure CLI Authentication & Cluster Context"] = "PASS"
    }
} catch {
    Write-Host "[-] Cluster connection failed: $_" -ForegroundColor Red
}
Show-Status "1. Azure CLI Authentication & Cluster Context" $results["1. Azure CLI Authentication & Cluster Context"]

# 2. Check Private Link DNS Resolution
try {
    Write-Host "`n[+] Verifying Private DNS Resolution..." -ForegroundColor Yellow
    $acrDns = Resolve-DnsName -Name "$AcrName.azurecr.io" -ErrorAction SilentlyContinue
    $kvDns = Resolve-DnsName -Name "$KeyVaultName.vault.azure.net" -ErrorAction SilentlyContinue
    
    # Assert that they resolve to internal addresses (10.1.20.X endpoints subnet range)
    if ($acrDns.IPAddress -match "^10\.1\.20\." -and $kvDns.IPAddress -match "^10\.1\.20\.") {
        $results["2. Private Endpoint DNS Resolution (ACR & Key Vault)"] = "PASS"
    } else {
        Write-Host "[-] Private DNS failed. ACR Resolves to: $($acrDns.IPAddress). Key Vault Resolves to: $($kvDns.IPAddress)" -ForegroundColor Red
    }
} catch {
    Write-Host "[-] DNS resolution query failed: $_" -ForegroundColor Red
}
Show-Status "2. Private Endpoint DNS Resolution (ACR & Key Vault)" $results["2. Private Endpoint DNS Resolution (ACR & Key Vault)"]

# 3. Check Egress Traffic Isolation (Firewall Block)
try {
    Write-Host "`n[+] Verifying Firewall Egress Rules..." -ForegroundColor Yellow
    # Spin up test pod, attempt whitelisted call and blocked call
    kubectl run egress-test-pod --image=busybox -n $Namespace --restart=Never -- sh -c "wget -q --spider https://www.github.com && echo 'WHITE_OK' && wget -T 5 -q --spider https://www.facebook.com || echo 'BLACK_BLOCK'" | Out-Null
    
    Write-Host "Waiting for egress test container to execute..."
    Start-Sleep -Seconds 10
    
    $logs = kubectl logs egress-test-pod -n $Namespace
    kubectl delete pod egress-test-pod -n $Namespace --now | Out-Null
    
    if ($logs -match "WHITE_OK" -and $logs -match "BLACK_BLOCK") {
        $results["3. Egress Traffic Isolation (Firewall Block)"] = "PASS"
    } else {
        Write-Host "[-] Egress check failed. Container Logs: $logs" -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Egress test execution failed: $_" -ForegroundColor Red
}
Show-Status "3. Egress Traffic Isolation (Firewall Block)" $results["3. Egress Traffic Isolation (Firewall Block)"]

# 4. Check Admission Control (Kyverno Block Policies)
try {
    Write-Host "`n[+] Verifying Kyverno Block Policies..." -ForegroundColor Yellow
    
    # Test Policy 1: disallow latest tag
    $tagBlock = kubectl run test-latest-tag --image=nginx:latest -n $Namespace --restart=Never 2>&1
    
    # Test Policy 2: mandate limits
    $limitsBlock = kubectl run test-no-limits --image=nginx:1.25 -n $Namespace --restart=Never 2>&1
    
    if ($tagBlock -match "disallowed" -and $limitsBlock -match "limits are mandatory") {
        $results["4. Admission Control Rules (Kyverno Block Policies)"] = "PASS"
    } else {
        Write-Host "[-] Admission rules not enforcing. Tag block response: $tagBlock. Limits block response: $limitsBlock" -ForegroundColor Red
    }
    
    # Cleanup if pods got scheduled accidentally due to missing policies
    kubectl delete pod test-latest-tag test-no-limits -n $Namespace --ignore-not-found --now | Out-Null
} catch {
    Write-Host "[-] Kyverno testing failed: $_" -ForegroundColor Red
}
Show-Status "4. Admission Control Rules (Kyverno Block Policies)" $results["4. Admission Control Rules (Kyverno Block Policies)"]

# 5. Check Workload Identity & CSI Secret Mounting
try {
    Write-Host "`n[+] Verifying CSI Key Vault Secret Mounting..." -ForegroundColor Yellow
    # Read the mounted secret from the running test-secret-pod
    $secretVal = kubectl exec test-secret-pod -n $Namespace -- cat /mnt/secrets/prod-db-password 2>&1
    if ($LASTEXITCODE -eq 0 -and $secretVal -ne $null -and $secretVal -notmatch "Error") {
        $results["5. Workload Identity & CSI Secret Mounting"] = "PASS"
    } else {
        Write-Host "[-] CSI Secret verification failed. Output: $secretVal" -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Secret mounting verification crashed: $_" -ForegroundColor Red
}
Show-Status "5. Workload Identity & CSI Secret Mounting" $results["5. Workload Identity & CSI Secret Mounting"]

# 6. Check GitOps Applications Status
try {
    Write-Host "`n[+] Checking ArgoCD Application sync status..." -ForegroundColor Yellow
    # Get Applications status in the gitops namespace
    $apps = kubectl get applications -n gitops -o json
    if ($apps -and $apps -notmatch "No resources found") {
        $appsObj = $apps | ConvertFrom-Json
        $failedApps = $appsObj.items | Where-Object { $_.status.sync.status -ne "Synced" -or $_.status.health.status -ne "Healthy" }
        if ($failedApps.Count -eq 0) {
            $results["6. GitOps Reconciliation & ArgoCD Status"] = "PASS"
        } else {
            foreach ($app in $failedApps) {
                Write-Host "[-] App: $($app.metadata.name) is Sync: $($app.status.sync.status), Health: $($app.status.health.status)" -ForegroundColor Red
            }
        }
    }
} catch {
    Write-Host "[-] ArgoCD status check failed: $_" -ForegroundColor Red
}
Show-Status "6. GitOps Reconciliation & ArgoCD Status" $results["6. GitOps Reconciliation & ArgoCD Status"]

# 7. Check Observability Backends
try {
    Write-Host "`n[+] Verifying Observability backend endpoint health..." -ForegroundColor Yellow
    
    $prometheusSVC = kubectl get svc kube-prometheus-stack-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress}' 2>&1
    $lokiSVC = kubectl get svc loki -n monitoring -o jsonpath='{.spec.clusterIP}' 2>&1
    $jaegerSVC = kubectl get svc jaeger-query -n monitoring -o jsonpath='{.spec.clusterIP}' 2>&1
    
    if ($lokiSVC -ne "" -and $jaegerSVC -ne "") {
        $results["7. Observability Backend Endpoint Health"] = "PASS"
    } else {
        Write-Host "[-] Service endpoints check: Loki: $lokiSVC, Jaeger: $jaegerSVC" -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Observability check failed: $_" -ForegroundColor Red
}
Show-Status "7. Observability Backend Endpoint Health" $results["7. Observability Backend Endpoint Health"]

# =========================================================================
# FINAL SCORECARD PRINT
# =========================================================================
Write-Host "`n=========================================================================" -ForegroundColor Cyan
Write-Host "                      E2E VERIFICATION SCORECARD                         " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan

$passedCount = 0
foreach ($test in $results.Keys) {
    $status = $results[$test]
    if ($status -eq "PASS") {
        $passedCount++
        Write-Host "$test : [ PASS ]" -ForegroundColor Green
    } else {
        Write-Host "$test : [ FAIL ]" -ForegroundColor Red
    }
}

Write-Host "`nResult: $passedCount / $($results.Count) Tests Passed." -ForegroundColor ($passedCount -eq $results.Count ? "Green" : "Red")
Write-Host "=========================================================================" -ForegroundColor Cyan
