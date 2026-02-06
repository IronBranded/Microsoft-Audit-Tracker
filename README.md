# MICROSOFT AUDIT TRACKER (MAT)
Cloud Response & Auditing Utility

Version: 1.0

Creator: M. Decayette (IronBranded)

========================================

[!] LEGAL DISCLAIMER & MANDATORY CONSENT
----------------------------------------
This tool is provided for professional security auditing and Incident Response
purposes only. Use of the Microsoft Audit Tracker (MAT) MUST be conducted ONLY
after obtaining EXPLICIT WRITTEN CONSENT from the Tenant Owners and Authorized 
Administrators. 

The user is solely responsible for ensuring that all activities comply with 
local laws, organizational policies, and privacy regulations. The developer 
assumes no liability for data loss, service interruption, or legal 
consequences resulting from the use of this tool.

--------------------------------------------------------------------------------
>> TABLE OF CONTENTS
--------------------------------------------------------------------------------
1.  Tool Description & IR Relevance
2.  How to Use (Windows & macOS)
3.  Required Permissions (RBAC)
4.  Operations Matrix
5.  Cloud IR Preparedness & Security Pillars
6.  References & Documentation

--------------------------------------------------------------------------------
1. TOOL DESCRIPTION & IR RELEVANCE
--------------------------------------------------------------------------------
Microsoft Audit Tracker (MAT) identifies the "Forensic Footprint"—the trail of 
evidence left behind by attackers—and determines if the tenant's current 
configuration is actually recording that evidence. 

The tool provides a unified view to determine if the appropriate logs and 
other relevant security pillars within the Microsoft Cloud solution stack 
are active. 

--------------------------------------------------------------------------------
2. HOW TO USE
--------------------------------------------------------------------------------
REQUIREMENTS:
* Windows: PowerShell 5.1 or PowerShell 7+
* macOS: PowerShell 7+ (pwsh) must be installed.

--- STARTING THE TOOL (WINDOWS) ---
1. Open PowerShell as Administrator.
2. Navigate to the folder:
   cd C:\Path\To\MicrosoftAuditTracker
3. Run the following command to bypass execution policy and start:
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
   .\Start-MAT.ps1

--- STARTING THE TOOL (macOS) ---
1. Open Terminal.
2. Navigate to the folder:
   cd /Users/YourName/Path/To/MicrosoftAuditTracker
3. Initiate the tool using PowerShell Core:
   pwsh ./Start-MAT.ps1

--------------------------------------------------------------------------------
3. REQUIRED PERMISSIONS (RBAC)
--------------------------------------------------------------------------------
To ensure full operational capability, the executing account should hold:

* M365 Roles: Global Administrator (Required for 'Activator' mode) or 
              Security Administrator (Required for most 'Auditor' functions).
* Azure Roles: Reader (at Root/Subscription level) to inventory Defender status.
* Minimum Rights: At a minimum, 'Security Reader' and 'Global Reader' allow 
                  for read-only assessments (Options 1, 2, and 3).

--------------------------------------------------------------------------------
4. OPERATIONS MATRIX
--------------------------------------------------------------------------------
[1] AUDITOR MODE   : Forensic Health Check (UAL Status, Mailbox Auditing, Retention).

[2] PROTECTOR MODE : Identity & Posture Check (Security Defaults, CA Policies).
                     Inventories specific Security Service Plans (Entra P1/P2, etc).

[3] LICENSOR MODE  : SKU Inventory. Translates technical IDs into human-readable names.

[4] SUPER AUDITOR  : Full-Spectrum Capture. Runs Modes 1, 2, and 3 sequentially.

[5] ACTIVATOR MODE : Remediation. Enables Unified Audit Logging (UAL) if found 
                     disabled. Requires 'ENABLE-UAL' confirmation.

--------------------------------------------------------------------------------
5. CLOUD IR PREPAREDNESS & SECURITY PILLARS
--------------------------------------------------------------------------------
MAT focuses on the health of the following pillars:

* Unified Audit Log (UAL): Central repository for M365 actions.
* Mailbox Auditing: Essential for detecting BEC.
* Audit Retention: Identifies if logs are stored beyond the 90-day default.
* Identity Guardrails: Checks status of Security Defaults and CA Policies.

--------------------------------------------------------------------------------
6. REFERENCES & DOCUMENTATION
--------------------------------------------------------------------------------
** Microsoft SKU & Service Plan Reference:
  https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference

** Microsoft Incident Response Team (M365 Artifacts):
  https://go.microsoft.com/fwlink/?linkid=2257423

** Microsoft licence matrix
https://m365maps.com/matrix.htm#000000000000000000000

--------------------------------------------------------------------------------
[#] OUTPUTS
--------------------------------------------------------------------------------
Reports are automatically exported to:
* Windows: Downloads\MAT_Reports\
* macOS:   ~/Downloads/MAT_Reports/

Operational logs (OA.txt) are created for every run to ensure non-repudiation.
================================================================================
