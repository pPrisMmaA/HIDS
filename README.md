# HIDS
The goal of this project was to develop a Host-based Intrusion Detection System (HIDS) using PowerShell. 

This system is designed to monitor the integrity of specific files and send email alerts to an administrator as soon as a change is detected. To achieve this, I separated the architecture into several components for greater clarity and security. The core engine is the HIDS-Monitor.ps1 script, which contains all the monitoring logic. Parameters, such as the paths of the files to monitor and the SMTP server information, are stored in an external JSON configuration file named HIDS-Config.json. SMTP credentials are managed securely using an SMTP_Credential.xml file, which stores the password in encrypted form. Integrity verification relies on a baseline named HIDS-Baseline.dat. This baseline is created the first time the HIDS-Monitor.ps1 script is run. The script calculates the SHA256 cryptographic hash of each target file using the Get-IntegrityHash function and stores these hashes in the HIDS-Baseline.dat file.

Once this baseline is established, the script enters a continuous monitoring loop (while ($true)). At regular intervals, it recalculates the hash of each file and compares it to the one stored in the baseline. If a hash differs, the script identifies a "CHANGE". If a file is inaccessible or deleted, the hash function returns a null value, which is interpreted as a "DELETION".

When a change or deletion is detected, the Send-HIDSAlert function is immediately called. It uses the Send-MailMessage cmdlet with an SSL connection to send a secure notification. The alert details are sent to the destination email address defined in the configuration file. After the alert is sent, the baseline is automatically updated with the new state of the file, preventing repeated alerts for a change that has already been reported.

Documentation :  
Installation et Configuration 
Le script requiert une arborescence de dossiers spécifique pour fonctionner. Il faut créer un dossier principal pour le projet (par exemple : C:\HIDS_Project). À l'intérieur de ce dossier, un sous-dossier nommé Data doit être créé. C'est ici que les fichiers de configuration et de baseline seront stockés. Un dossier contenant les fichiers à surveiller doit exister (par exemple : C:\HIDS_Test). Fichier de configuration (HIDS-Config.json) Ce fichier définit les cibles de surveillance et les paramètres de notification. Un fichier nommé HIDS-Config.json doit être créé. Il doit être placé dans le dossier C:\HIDS_Project\Data. Ce fichier JSON doit contenir les clés 
suivantes : 
1) Paths : Une liste des chemins complets vers les fichiers à surveiller (en utilisant des 
doubles anti-slash \\). 
2) SMTPServer : L'adresse du serveur SMTP (ex: "smtp.gmail.com"). 
SMTPPort : Le port du serveur SMTP (ex: 587). 
3) From, Username, To : Les adresses email pour l'expédition et la réception des alertes. Fichier d'identifiants sécurisés (SMTP_Credential.xml) Pour des raisons de sécurité, le mot de passe SMTP ne doit pas être stocké en clair. Il est nécessaire d'ouvrir une console PowerShell et d'exécuter la commande $Cred = Get-Credential. Une fenêtre sécurisée demandera le nom d'utilisateur (l'email From) et le mot de passe (le mot de passe d'application généré). Cet objet PSCredential doit ensuite être exporté à l'aide de la commande suivante, en respectant le chemin attendu par le script :

PowerShell 
$Cred | Export-Clixml -Path "C:\HIDS_Project\Data\SMTP_Credential.xml" 

Placement du script 
Le script HIDS-Monitor.ps1 doit être placé à la racine du dossier projet (ex: 
C:\HIDS_Project). 

Utilisation du HIDS 
Lancement initial (Création de la Baseline) 
Le premier lancement du script est une étape d'initialisation. Il faut exécuter le script .\HIDS-Monitor.ps1 depuis une console PowerShell. Le script détectera l'absence du 
fichier HIDS-Baseline.dat et affichera "Baseline absente. Création initiale...". Il calculera le hash SHA256 de chaque fichier listé dans HIDS-Config.json et sauvegardera le résultat dans C:\HIDS_Project\Data\HIDS-Baseline.dat. L'opération sera confirmée par le message " Baseline initiale créée et sauvegardée.". Surveillance Active 
Une fois la baseline créée, le script entre en mode de surveillance continue. 
• Le message "HIDS démarré. Surveillance active et continue..." s'affichera. 
• Toutes les 20 secondes, un message d'état "Aucun changement détecté..." 
apparaîtra, confirmant le bon déroulement de la vérification. 
• Pour une exécution en arrière-plan (une exigence du projet ), une idée serait de configurer une Tâche planifiée Windows pour que le script HIDS-Monitor.ps1 se 
lançant au démarrage du système.

Gestion des Alertes 
En cas d'anomalie, le script réagit de la manière suivante : 
Une alerte (MODIFICATION ou SUPPRESSION) est affichée dans la console si un des fichiers surveillés est modifié (ajout ou suppression) ou supprimé. Dès lors la fonction 
Send-HIDSAlert est déclenchée pour envoyer un email détaillé à l'administrateur (email et fichier surveillé sont définis dans le fichier de configuration). Immédiatement après l'envoi de l'alerte, la baseline (HIDS-Baseline.dat) est mise à jour avec le nouvel état (nouveau hash ou suppression de l'entrée). Cela empêche l'envoi d'alertes multiples pour un seul et même événement. Le script HIDS-Monitor.ps1 ne modifie jamais le fichier de configuration HIDS-Config.json, il ne fait que le lire. Lorsqu'un fichier surveillé est supprimé, le script envoie une alerte, puis met à jour sa baseline (HIDSBaseline.dat) en supprimant l'entrée correspondante. Si c'était le seul fichier surveillé, le script continue de tourner à vide. Pour que la surveillance reprenne, il ne suffit pas de recréer le fichier ; il faut également supprimer manuellement l'ancienne baseline et relancer le script pour qu'il la recrée à partir du fichier de configuration. 

Structure complète du dossier

C:\HIDS_Project\
│
├── Data\
│   ├── HIDS-Config.json          ← À créer manuellement
│   ├── SMTP_Credential.xml       ← À créer avec le script PowerShell
│   └── HIDS-Baseline.dat         ← Créé automatiquement au 1er lancement
│
└── HIDS-Monitor.ps1               ← Le script principal
