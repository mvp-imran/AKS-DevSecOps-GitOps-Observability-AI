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
    "8. Service Mesh Control Plane Health (Istio)" = "FAIL"
    "9. Backup Storage & Backup Configuration (Velero)" = "FAIL"
    "10. FinOps Autoscaling Enforcement Check (HPA)" = "FAIL"
    "11. Disaster Recovery Routing Availability Check (Front Door)" = "FAIL"
    "12. AIOps Connector Function App Status" = "FAIL"
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
    
    # Test Policy 3: block privileged container escalation
    $privilegedYaml = @"
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged-escalation
  namespace: $Namespace
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "128Mi"
      requests:
        cpu: "50m"
        memory: "64Mi"
    securityContext:
      privileged: true
"@
    $privilegedYamlPath = Join-Path $env:TEMP "test-privileged.yaml"
    $privilegedYaml | Out-File -FilePath $privilegedYamlPath -Encoding utf8
    $privilegedBlock = kubectl apply -f $privilegedYamlPath 2>&1
    Remove-Item $privilegedYamlPath -ErrorAction SilentlyContinue

    if ($tagBlock -match "disallowed" -and $limitsBlock -match "limits are mandatory" -and $privilegedBlock -match "privileged containers are disallowed") {
        $results["4. Admission Control Rules (Kyverno Block Policies)"] = "PASS"
    } else {
        Write-Host "[-] Admission rules not enforcing. Tag block response: $tagBlock. Limits block response: $limitsBlock. Privileged block response: $privilegedBlock" -ForegroundColor Red
    }
    
    # Cleanup if pods got scheduled accidentally due to missing policies
    kubectl delete pod test-latest-tag test-no-limits test-privileged-escalation -n $Namespace --ignore-not-found --now | Out-Null
} catch {
    Write-Host "[-] Kyverno testing failed: $_" -ForegroundColor Red
}
Show-Status "4. Admission Control Rules (Kyverno Block Policies)" $results["4. Admission Control Rules (Kyverno Block Policies)"]

# 5. Check Workload Identity & CSI Secret Mounting (Automated Pod lifecycle)
try {
    Write-Host "`n[+] Verifying CSI Key Vault Secret Mounting (Creating temporary pod)..." -ForegroundColor Yellow
    $miClientId = az identity show --name "mi-customer-api-dev" --resource-group $ResourceGroupName --query "clientId" -o tsv 2>&1
    $tenantId = az account show --query "tenantId" -o tsv 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $miClientId -ne "" -and $tenantId -ne "") {
        $tempYaml = @"
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: e2e-kv-provider
  namespace: $Namespace
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    userAssignedIdentityID: "$miClientId"
    keyvaultName: "$KeyVaultName"
    cloudName: ""
    objects:  |
      array:
        - |
          objectName: prod-db-password
          objectType: secret
          objectVersion: ""
    tenantId: "$tenantId"
---
apiVersion: v1
kind: Pod
metadata:
  name: e2e-secret-pod
  namespace: $Namespace
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: customer-api-sa
  containers:
  - name: web
    image: nginx:1.25-alpine
    resources:
      limits:
        cpu: "100m"
        memory: "128Mi"
      requests:
        cpu: "50m"
        memory: "64Mi"
    volumeMounts:
    - name: secrets-store-inline
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secrets-store-inline
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "e2e-kv-provider"
"@
        $tempYamlPath = Join-Path $env:TEMP "e2e-secret-test.yaml"
        $tempYaml | Out-File -FilePath $tempYamlPath -Encoding utf8
        kubectl apply -f $tempYamlPath | Out-Null
        
        Write-Host "Waiting for secrets test pod to start (up to 45 seconds)..."
        $timeout = 45
        $elapsed = 0
        $podReady = $false
        while ($elapsed -lt $timeout) {
            $status = kubectl get pod e2e-secret-pod -n $Namespace -o jsonpath='{.status.phase}' 2>&1
            if ($status -eq "Running") {
                $podReady = $true
                break
            }
            Start-Sleep -Seconds 3
            $elapsed += 3
        }
        
        if ($podReady) {
            $secretVal = kubectl exec e2e-secret-pod -n $Namespace -- cat /mnt/secrets/prod-db-password 2>&1
            if ($LASTEXITCODE -eq 0 -and $secretVal -ne $null -and $secretVal -notmatch "Error") {
                $results["5. Workload Identity & CSI Secret Mounting"] = "PASS"
            } else {
                Write-Host "[-] CSI Secret verification failed. Output: $secretVal" -ForegroundColor Red
            }
        } else {
            Write-Host "[-] Secrets test pod failed to reach Running state." -ForegroundColor Red
        }
        
        # Cleanup
        kubectl delete -f $tempYamlPath --ignore-not-found --now | Out-Null
        Remove-Item $tempYamlPath -ErrorAction SilentlyContinue
    } else {
        Write-Host "[-] Managed identity or Tenant retrieval failed. ClientID: $miClientId, TenantID: $tenantId" -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Secret mounting verification crashed: $_" -ForegroundColor Red
}
Show-Status "5. Workload Identity & CSI Secret Mounting" $results["5. Workload Identity & CSI Secret Mounting"]

# 6. Check GitOps Applications Status (Supports ArgoCD & Flux)
try {
    Write-Host "`n[+] Checking GitOps sync status..." -ForegroundColor Yellow
    $hasArgo = kubectl get crd 2>&1 | Select-String "applications.argoproj.io" -Quiet
    $hasFlux = kubectl get crd 2>&1 | Select-String "kustomizations.kustomize.toolkit.fluxcd.io" -Quiet
    
    if ($hasArgo) {
        Write-Host "[*] ArgoCD detected. Checking applications..."
        $apps = kubectl get applications -n gitops -o json
        if ($apps -and $apps -notmatch "No resources") {
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
    } elseif ($hasFlux) {
        Write-Host "[*] Flux detected. Checking kustomizations..."
        $kusts = kubectl get kustomizations -A -o json
        if ($kusts -and $kusts -notmatch "No resources") {
            $kustsObj = $kusts | ConvertFrom-Json
            $failedKusts = $kustsObj.items | Where-Object { $_.status.conditions[0].status -ne "True" }
            if ($failedKusts.Count -eq 0) {
                $results["6. GitOps Reconciliation & ArgoCD Status"] = "PASS"
            } else {
                foreach ($k in $failedKusts) {
                    Write-Host "[-] Flux Kustomization: $($k.metadata.name) is unhealthy." -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "[-] No GitOps operator (ArgoCD or Flux) CRDs found in cluster." -ForegroundColor Red
    }
} catch {
    Write-Host "[-] GitOps status check failed: $_" -ForegroundColor Red
}
Show-Status "6. GitOps Reconciliation & ArgoCD Status" $results["6. GitOps Reconciliation & ArgoCD Status"]

# 7. Check Observability Backends
try {
    Write-Host "`n[+] Verifying Observability backend endpoint health..." -ForegroundColor Yellow
    
    $lokiExists = kubectl get svc -n monitoring -o jsonpath='{.items[*].metadata.name}' 2>&1 | Select-String "loki" -Quiet
    $jaegerExists = kubectl get svc -n monitoring -o jsonpath='{.items[*].metadata.name}' 2>&1 | Select-String "jaeger" -Quiet
    $promExists = kubectl get svc -n monitoring -o jsonpath='{.items[*].metadata.name}' 2>&1 | Select-String "prometheus" -Quiet
    $grafanaExists = kubectl get svc -n monitoring -o jsonpath='{.items[*].metadata.name}' 2>&1 | Select-String "grafana" -Quiet
    
    if ($lokiExists -and $jaegerExists -and $promExists -and $grafanaExists) {
        $results["7. Observability Backend Endpoint Health"] = "PASS"
    } else {
        Write-Host "[-] Observability services check: Loki: $lokiExists, Jaeger: $jaegerExists, Prometheus: $promExists, Grafana: $grafanaExists" -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Observability check failed: $_" -ForegroundColor Red
}
Show-Status "7. Observability Backend Endpoint Health" $results["7. Observability Backend Endpoint Health"]

# 8. Check Service Mesh Control Plane Health (Istio)
try {
    Write-Host "`n[+] Verifying Istio Service Mesh..." -ForegroundColor Yellow
    
    # Check either aks-istio-system (Azure managed) or istio-system (self-managed)
    $meshNamespace = "aks-istio-system"
    $istiodPods = kubectl get pods -n $meshNamespace -o json 2>&1
    if ($istiodPods -match "No resources" -or $istiodPods -match "Error") {
        $meshNamespace = "istio-system"
        $istiodPods = kubectl get pods -n $meshNamespace -o json 2>&1
    }
    
    if ($istiodPods -and $istiodPods -notmatch "Error" -and $istiodPods -notmatch "No resources") {
        $istiodObj = $istiodPods | ConvertFrom-Json
        $runningIstiod = $istiodObj.items | Where-Object { $_.status.phase -eq "Running" }
        if ($runningIstiod) {
            $results["8. Service Mesh Control Plane Health (Istio)"] = "PASS"
        } else {
            Write-Host "[-] Istio control plane pods found but none are Running." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Istio namespace/pods not found." -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Istio mesh health check failed: $_" -ForegroundColor Red
}
Show-Status "8. Service Mesh Control Plane Health (Istio)" $results["8. Service Mesh Control Plane Health (Istio)"]

# 9. Check Backup Storage & Backup Configuration (Velero)
try {
    Write-Host "`n[+] Verifying Velero backup system health..." -ForegroundColor Yellow
    
    # Assert velero storage account is active
    $veleroStorageAccountName = "savelero" + $Namespace + "eus"
    $veleroStorage = az storage account show --name $veleroStorageAccountName --resource-group $ResourceGroupName --query "provisioningState" -o tsv 2>&1
    
    # Check Velero CRD and pod status in cluster
    $veleroCrd = kubectl get crd 2>&1 | Select-String "backups.velero.io" -Quiet
    $veleroPods = kubectl get pods -A -l "app.kubernetes.io/name=velero" -o json 2>&1
    
    if ($veleroCrd -and $veleroPods -notmatch "No resources" -and $veleroPods -notmatch "Error") {
        $veleroObj = $veleroPods | ConvertFrom-Json
        $runningVelero = $veleroObj.items | Where-Object { $_.status.phase -eq "Running" }
        if ($runningVelero -and $veleroStorage -match "Succeeded") {
            $results["9. Backup Storage & Backup Configuration (Velero)"] = "PASS"
        } else {
            Write-Host "[-] Velero check failed. Running pods: $($runningVelero.Count), Storage status: $veleroStorage" -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Velero CRDs or pods not found in cluster." -ForegroundColor Red
    }
} catch {
    Write-Host "[-] Velero check failed: $_" -ForegroundColor Red
}
Show-Status "9. Backup Storage & Backup Configuration (Velero)" $results["9. Backup Storage & Backup Configuration (Velero)"]

# 10. Check FinOps Autoscaling Enforcement Check (HPA)
try {
    Write-Host "`n[+] Verifying HPA Configuration..." -ForegroundColor Yellow
    
    $hpas = kubectl get hpa -n $Namespace -o json 2>&1
    if ($hpas -and $hpas -notmatch "No resources" -and $hpas -notmatch "Error") {
        $hpaObj = $hpas | ConvertFrom-Json
        if ($hpaObj.items.Count -gt 0) {
            $results["10. FinOps Autoscaling Enforcement Check (HPA)"] = "PASS"
        } else {
            Write-Host "[-] No HPAs configured in namespace $Namespace." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] HPA resource query returned empty or failed." -ForegroundColor Red
    }
} catch {
    Write-Host "[-] HPA check failed: $_" -ForegroundColor Red
}
Show-Status "10. FinOps Autoscaling Enforcement Check (HPA)" $results["10. FinOps Autoscaling Enforcement Check (HPA)"]

# 11. Check Disaster Recovery Routing Availability Check (Front Door)
try {
    Write-Host "`n[+] Verifying Disaster Recovery Front Door Endpoint..." -ForegroundColor Yellow
    
    # Get Front Door endpoint name or check availability
    $fdHost = "endpoint-customer-api-$Namespace.azurefd.net"
    Write-Host "Querying Front Door URL: https://$fdHost/healthz"
    
    # Perform dns lookup and web request
    $fdDns = Resolve-DnsName -Name $fdHost -ErrorAction SilentlyContinue
    $statusCode = $null
    try {
        $webReq = Invoke-WebRequest -Uri "https://$fdHost/healthz" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $statusCode = $webReq.StatusCode
    } catch {
        # Extract HTTP status code from the exception if available
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
    }
    
    if ($fdDns -and ($statusCode -eq 200 -or $statusCode -eq 502 -or $statusCode -eq 503)) {
        $results["11. Disaster Recovery Routing Availability Check (Front Door)"] = "PASS"
    } else {
        Write-Host "[-] Front Door validation failed. DNS Resolves: $($fdDns -ne $null). Status code returned: $statusCode" -ForegroundColor Red
    }
} catch {
    Write-Host "[-] DR Front Door check failed: $_" -ForegroundColor Red
}
Show-Status "11. Disaster Recovery Routing Availability Check (Front Door)" $results["11. Disaster Recovery Routing Availability Check (Front Door)"]

# 12. Check AIOps Connector Function App Status
try {
    Write-Host "`n[+] Verifying AIOps Connector Function App status..." -ForegroundColor Yellow
    
    # Check for func-aiops-connector-dev or similar Function App
    $funcApp = az functionapp list --resource-group $ResourceGroupName --query "[?contains(name, 'aiops')]" -o json 2>&1
    if ($funcApp -and $funcApp -notmatch "Error") {
        $funcObj = $funcApp | ConvertFrom-Json
        if ($funcObj.Count -gt 0) {
            $runningFunc = $funcObj | Where-Object { $_.state -eq "Running" }
            if ($runningFunc) {
                $results["12. AIOps Connector Function App Status"] = "PASS"
            } else {
                Write-Host "[-] AIOps Function App found but it is in state: $($funcObj[0].state)" -ForegroundColor Red
            }
        } else {
            Write-Host "[-] No function app containing 'aiops' in name was found." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Function App query failed." -ForegroundColor Red
    }
} catch {
    Write-Host "[-] AIOps Connector verification failed: $_" -ForegroundColor Red
}
Show-Status "12. AIOps Connector Function App Status" $results["12. AIOps Connector Function App Status"]

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

$resultColor = "Red"
if ($passedCount -eq $results.Count) { $resultColor = "Green" }
Write-Host "`nResult: $passedCount / $($results.Count) Tests Passed." -ForegroundColor $resultColor
Write-Host "=========================================================================" -ForegroundColor Cyan
