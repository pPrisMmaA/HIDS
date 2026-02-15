# HIDS
The goal of this project was to develop a Host-based Intrusion Detection System (HIDS) using PowerShell. 

Complete Directory Structure

C:\HIDS_Project\
│

├── Data\

│   ├── HIDS-Config.json          ← To create manually : HIDS-Config.json is a JSON-formatted configuration file that stores essential operational parameters for the HIDS system, including SMTP server settings for email alerts and the list of file paths to monitor for integrity violations. The file must be created manually before the first execution of HIDS-Monitor.ps1, typically using the Configure-HIDS.ps1 setup script, as the monitoring system cannot function without these configuration parameters. This file contains structured data including SMTP server address, port number, sender and recipient email addresses, and an array of absolute file paths that the system will continuously monitor for unauthorized modifications. Unlike HIDS-Baseline.dat, this file is human-readable and can be manually edited with any text editor, allowing administrators to add comments, modify monitored paths, or update SMTP settings as needed. The file is loaded at the beginning of each script execution and its parameters are used throughout the monitoring process to determine which files to watch and how to send security alerts.

│   ├── SMTP_Credential.xml       ← To create with with PowerShell 

│   └── HIDS-Baseline.dat         ← Automatically created during the first execution of HIDS-Monitor.ps1 : PowerShell-serialized binary file that stores the SHA256 hash values of all monitored files, serving as the reference point for detecting unauthorized modifications. The file is automatically created during the first execution of HIDS-Monitor.ps1 when no baseline exists, and it is subsequently updated whenever file changes are detected and verified. This file contains a hashtable mapping each monitored file path to its corresponding SHA256 hash, enabling the system to identify integrity violations by comparing current file hashes against the stored baseline values. The file cannot be manually edited or commented because it uses PowerShell's CliXML serialization format, which requires exact binary structure for successful deserialization by the Import-Clixml command.

│

└── HIDS-Monitor.ps1               ← Main script
This system is designed to monitor the integrity of specific files and send email alerts to an administrator as soon as a change is detected. To achieve this, I separated the architecture into several components for greater clarity and security. The core engine is the HIDS-Monitor.ps1 script, which contains all the monitoring logic. Parameters, such as the paths of the files to monitor and the SMTP server information, are stored in an external JSON configuration file named HIDS-Config.json. SMTP credentials are managed securely using an SMTP_Credential.xml file, which stores the password in encrypted form. Integrity verification relies on a baseline named HIDS-Baseline.dat. This baseline is created the first time the HIDS-Monitor.ps1 script is run. The script calculates the SHA256 cryptographic hash of each target file using the Get-IntegrityHash function and stores these hashes in the HIDS-Baseline.dat file.

Once this baseline is established, the script enters a continuous monitoring loop (while ($true)). At regular intervals, it recalculates the hash of each file and compares it to the one stored in the baseline. If a hash differs, the script identifies a "CHANGE". If a file is inaccessible or deleted, the hash function returns a null value, which is interpreted as a "DELETION".

When a change or deletion is detected, the Send-HIDSAlert function is immediately called. It uses the Send-MailMessage cmdlet with an SSL connection to send a secure notification. The alert details are sent to the destination email address defined in the configuration file. After the alert is sent, the baseline is automatically updated with the new state of the file, preventing repeated alerts for a change that has already been reported.

Documentation:
Installation and Configuration
The script requires a specific folder structure to function. A main folder must be created for the project (e.g., C:\HIDS_Project). Inside this folder, a subfolder named Data must be created. This is where the configuration and baseline files will be stored. A folder containing the files to be monitored must also exist (e.g., C:\HIDS_Test). Configuration File (HIDS-Config.json) This file defines the monitoring targets and notification parameters. A file named HIDS-Config.json must be created and placed in the C:\HIDS_Project\Data folder. This JSON file must contain the following keys:

1) Paths: A list of the full paths to the files to be monitored (using double backslashes \\).

2) SMTPServer: The address of the SMTP server (e.g., "smtp.gmail.com").
SMTPPort: The SMTP server port (e.g., 587).

3) From, Username, To: The email addresses for sending and receiving alerts. Secure credentials file (SMTP_Credential.xml): For security reasons, the SMTP password must not be stored in plain text. You must open a PowerShell console and run the command `$Cred = Get-Credential`. A secure window will prompt you for the username (the From email address) and the password (the generated application password). This PSCredential object must then be exported using the following command, respecting the path expected by the script:

PowerShell
$Cred | Export-Clixml -Path "C:\HIDS_Project\Data\SMTP_Credential.xml"

Script Placement
The HIDS-Monitor.ps1 script must be placed in the root directory of the project folder (e.g., C:\HIDS_Project).

Using HIDS
Initial Launch (Baseline Creation)
The first time the script is run, it's an initialization step. You must run the .\HIDS-Monitor.ps1 script from a PowerShell console. The script will detect the absence of the HIDS-Baseline.dat file and display "Baseline missing. Initial creation...". It will calculate the SHA256 hash of each file listed in HIDS-Config.json and save the result to C:\HIDS_Project\Data\HIDS-Baseline.dat. The operation will be confirmed by the message "Initial Baseline created and saved.". Active Monitoring
Once the baseline is created, the script enters continuous monitoring mode.

• The message "HIDS started. Active and continuous monitoring..." will be displayed.

• Every 20 seconds, a status message "No changes detected..." will appear, confirming that the check is running successfully.

• For background execution (a project requirement), one approach would be to configure a Windows scheduled task so that the HIDS-Monitor.ps1 script starts
when the system boots.

Alert Management
In case of an anomaly, the script reacts as follows:
An alert (MODIFICATION or DELETION) is displayed in the console if one of the monitored files is modified (added or deleted) or deleted. The
Send-HIDSAlert function is then triggered to send a detailed email to the administrator (email and monitored file are defined in the configuration file). Immediately after the alert is sent, the baseline (HIDS-Baseline.dat) is updated with the new state (new hash or deletion of the entry). This prevents multiple alerts from being sent for the same event. The HIDS-Monitor.ps1 script never modifies the HIDS-Config.json configuration file; it only reads it. When a monitored file is deleted, the script sends an alert and then updates its baseline (HIDSBaseline.dat) by deleting the corresponding entry. If this was the only monitored file, the script continues to run without executing any further actions. To resume monitoring, simply recreating the file is not enough; the old baseline must also be manually deleted, and the script must be rerun to recreate it from the configuration file.
