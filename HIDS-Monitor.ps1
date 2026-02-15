$DataDir = "C:\HIDS_Project\Data"
$ConfigFilePath = "$DataDir\HIDS-Config.json"
$CredentialFilePath = "$DataDir\SMTP_Credential.xml"
$BaselineFile = "$DataDir\HIDS-Baseline.dat"

# --- 2. Fonction : Calculer le hash SHA256 d’un fichier ---
function Get-IntegrityHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    try {
        (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
    } catch {
        return $null
    }
}

# --- 3. Fonction : Envoi d’une alerte e-mail sécurisée ---
function Send-HIDSAlert {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    try {
        # Lecture de la configuration SMTP
        if (-not (Test-Path $ConfigFilePath)) {
            Write-Error "Fichier de configuration introuvable : $ConfigFilePath"
            return
        }
        $Config = Get-Content $ConfigFilePath -Raw | ConvertFrom-Json

        # Import direct du credential complet (déjà PSCredential)
        if (-not (Test-Path $CredentialFilePath)) {
            Write-Error "Fichier d’identifiants introuvable : $CredentialFilePath"
            return
        }
        $Credential = Import-Clixml $CredentialFilePath

        # Test rapide de connectivité SMTP
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($Config.SMTPServer, [int]$Config.SMTPPort)
            $tcpClient.Close()
        } catch {
            Write-Warning " Impossible de joindre le serveur SMTP ($($Config.SMTPServer):$($Config.SMTPPort))"
        }

        # Envoi du mail
        Send-MailMessage -To $Config.To `
                         -From $Config.From `
                         -Subject $Subject `
                         -Body $Body `
                         -SmtpServer $Config.SMTPServer `
                         -Port $Config.SMTPPort `
                         -Credential $Credential `
                         -UseSsl `
                         -ErrorAction Stop

        Write-Host " Alerte envoyée : $Subject" -ForegroundColor Magenta
    }
    catch {
        Write-Error " Échec de l’envoi de l’alerte email : $($_.Exception.Message)"
    }
}

# --- 4. Chargement ou création de la baseline ---
try {
    $Config = Get-Content $ConfigFilePath -Raw | ConvertFrom-Json
    $PathsToMonitor = $Config.Paths
} catch {
    Write-Error "Erreur : fichier de configuration illisible ou manquant. Exécutez Configure-HIDS.ps1 d’abord."
    exit 1
}

if (-not (Test-Path $BaselineFile)) {
    Write-Host "Baseline absente. Création initiale..." -ForegroundColor Blue
    $Baseline = @{}

    foreach ($Path in $PathsToMonitor) {
        $Hash = Get-IntegrityHash -FilePath $Path
        if ($Hash) {
            $Baseline[$Path] = $Hash
        } else {
            Write-Warning " Chemin $Path inaccessible ou inexistant."
        }
    }

    $Baseline | Export-Clixml -Path $BaselineFile
    Write-Host " Baseline initiale créée et sauvegardée." -ForegroundColor Green
} else {
    Write-Host "Chargement de la baseline existante..." -ForegroundColor Blue
    $Baseline = Import-Clixml $BaselineFile
}

# --- 5. Boucle principale de surveillance ---
Write-Host "HIDS démarré. Surveillance active et continue..." -ForegroundColor Green

while ($true) {
    $NewBaseline = $Baseline.Clone()
    $Alerts = @()
    $ChangesDetected = $false

    # Vérification de modifications ou suppressions
    foreach ($Path in $Baseline.Keys) {
        $CurrentHash = Get-IntegrityHash -FilePath $Path

        if (-not $CurrentHash) {
            $Alerts += "SUPPRESSION : Le fichier [$Path] a été supprimé ou est inaccessible."
            $NewBaseline.Remove($Path)
            $ChangesDetected = $true
        }
        elseif ($CurrentHash -ne $Baseline[$Path]) {
            $Alerts += "MODIFICATION : L’intégrité du fichier [$Path] a été compromise. Nouveau hash : $CurrentHash."
            $NewBaseline[$Path] = $CurrentHash
            $ChangesDetected = $true
        }
    }

    # Réponse et mise à jour
    if ($ChangesDetected) {
        $Subject = "ALERTE HIDS - Changement détecté sur $($env:COMPUTERNAME)"
        $Body = "Les modifications suivantes ont été détectées :`n`n" + ($Alerts -join "`n")
        
        Send-HIDSAlert -Subject $Subject -Body $Body
        
        $NewBaseline | Export-Clixml -Path $BaselineFile
        $Baseline = $NewBaseline
        Write-Host "Baseline mise à jour suite aux changements." -ForegroundColor Yellow
    } else {
        Write-Host "Aucun changement détecté. ($(Get-Date -Format 'HH:mm:ss'))"
    }

    Start-Sleep -Seconds 20
}
