# MICROSOFT-AUDIT-TRACKER (MAT)
Cloud Response & Auditing Utility

**Version: 1.2**
Creator: M. Decayette (IronBranded)

---

## LEGAL DISCLAIMER & MANDATORY CONSENT

This tool is provided for professional security auditing and Incident Response purposes only.
Use of MAT **MUST** be conducted only after obtaining **explicit written consent** from the
Tenant Owners and Authorized Administrators.

The user is solely responsible for ensuring all activities comply with local laws,
organizational policies, and privacy regulations. The developer assumes no liability for
data loss, service interruption, or legal consequences resulting from use of this tool.

---

## TABLE OF CONTENTS

1. Tool Description & IR Relevance
2. File Structure
3. How to Use (Windows & macOS)
4. Privileged Identity Management (PIM) Note
5. Required Permissions — Per-Mode Matrix
6. Graph API Scopes
7. Operations Matrix
8. Copilot AI Audit Integration
9. Cloud IR Preparedness & Security Pillars
10. HTML Executive Report
11. Outputs
12. References

---

## 1. TOOL DESCRIPTION & IR RELEVANCE

Microsoft Audit Tracker (MAT) identifies the "Forensic Footprint" capabilities of a Microsoft 365
tenant and determines whether the current configuration is actually capturing the evidence an IR
team would need. It provides a unified view of audit logging health, identity posture, defensive
stack licensing, and AI governance — all in a single run with no manual API queries.

**v1.2 additions:**
- Copilot AI audit integrated natively into Auditor, Protector, and Licensor modes
- External auto-forwarding check (primary BEC persistence vector)
- Legacy authentication block detection
- PIM standing Global Administrator access detection
- CA policy MFA grant coverage (distinguishes "has CA" from "has MFA-enforcing CA")
- Retention thresholds evaluated (not just displayed)
- Single-pass CSV loading in HTML report (4 file reads vs 12)
- SKU data cache eliminates redundant Graph calls across SuperAuditor runs
- HTML report: collapsible sections, sticky nav, row-level severity highlighting,
  Key Findings panel, zebra striping, healthy count, dynamic Copilot colspan

---

## 2. FILE STRUCTURE

All files live **flat** in the same directory as `Start-MAT.ps1`:

```
MicrosoftAuditTracker/
├── Start-MAT.ps1          Entry point
├── MAT_State.ps1          Global state, SKU cache helper
├── MAT_Logging.ps1        Operator audit trail (non-repudiation)
├── MAT_Paths.ps1          Cross-platform report/log path resolution
├── MAT_Connection.ps1     Authentication, session management
├── MAT_UI_Engine.ps1      Console header and menu loop
├── LicenseMap.ps1         SKU and Defender service-plan reference data
├── Auditor.ps1            Mode 1 — Forensic Health Check
├── Protector.ps1          Mode 2 — Identity & Posture Check
├── Licensor.ps1           Mode 3 — Defensive Stack & License Inventory
├── Activator.ps1          Mode 5 — UAL remediation
├── Diagnostic.ps1         [D] — Environment diagnostic check
└── SuperAuditor.ps1       Mode 4 — Full-spectrum audit + HTML report
```

---

## 3. HOW TO USE

### Requirements

| Platform | PowerShell Version  |
|----------|---------------------|
| Windows  | 5.1 or 7+           |
| macOS    | 7+ (pwsh)           |

### Install required modules

```powershell
Install-Module Microsoft.Graph.Authentication -Force
Install-Module ExchangeOnlineManagement -Force   # v3.2+ required for Copilot record type
Install-Module Az.Accounts -Force                # Optional — Azure RBAC + diagnostic checks
Install-Module Az.Monitor  -Force                # Optional — Entra ID diagnostic settings
```

### Windows

```powershell
# Open PowerShell as Administrator
cd C:\Path\To\MicrosoftAuditTracker
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
.\Start-MAT.ps1
```

### macOS / Linux

```bash
cd /path/to/MicrosoftAuditTracker
pwsh ./Start-MAT.ps1
```

---

## 4. PRIVILEGED IDENTITY MANAGEMENT (PIM) NOTE

MAT detects **currently active** M365 role assignments via `Get-MgUserMemberOf`.
PIM-eligible roles that have **not been activated** for the current session are invisible
to this call and will display as "Standard User" in the MAT header.

**Before running MAT**, activate any required PIM role in the Entra admin center:
`Identity Governance → Privileged Identity Management → My roles → Activate`

Roles that require activation before specific modes will work correctly:
- Global Administrator or Compliance Administrator → required for Activator mode [5]
- Security Administrator or higher → recommended for full Auditor/Protector coverage

---

## 5. REQUIRED PERMISSIONS — PER-MODE MATRIX

### Mode 1 — Auditor (read-only)

| Layer         | Minimum permission |
|---------------|--------------------|
| M365 Role     | Security Reader (or Global Reader, Compliance Admin, Security Admin, Global Admin) |
| Exchange Role | View-Only Audit Reports; View-Only Configuration |
| Azure Role    | **Monitoring Reader** — required for Entra ID diagnostic endpoint. Generic "Reader" is NOT sufficient for `/providers/Microsoft.aadiam/diagnosticSettings`. Reader on subscription is sufficient for Azure Activity Log check. |
| Graph Scopes  | `AuditLog.Read.All`, `Directory.Read.All` |

### Mode 2 — Protector (read-only)

| Layer        | Minimum permission |
|--------------|--------------------|
| M365 Role    | Security Reader |
| Exchange     | None required |
| Azure        | None required |
| Graph Scopes | `Directory.Read.All`, `Policy.Read.All` — CA policy queries will always fail without `Policy.Read.All`, regardless of M365 admin role |

### Mode 3 — Licensor (read-only)

| Layer        | Minimum permission |
|--------------|--------------------|
| M365 Role    | Global Reader or Security Reader |
| Exchange     | None required |
| Azure        | None required |
| Graph Scopes | `Directory.Read.All`, `Reports.Read.All` (for Copilot usage summary) |

### Mode 4 — Super Auditor (read-only)

Union of Modes 1, 2, and 3. Recommended minimum: **Security Administrator** or
**Compliance Administrator** with **Monitoring Reader** on Azure.

### Mode 5 — Activator (write — tenant-level change)

| Layer        | Requirement |
|--------------|-------------|
| M365 Role    | **Global Administrator** OR **Compliance Administrator** — both hold the Exchange "Audit Logs" management role required by `Set-AdminAuditLogConfig`. Security Administrator does NOT have this right. |
| Exchange     | Audit Logs management role (held automatically by GA and Compliance Admin) |
| Azure        | None required |

---

## 6. GRAPH API SCOPES

All scopes are requested at connection time. Re-connect with [C] if a scope is missing.

| Scope | Required for |
|-------|-------------|
| `Directory.Read.All` | Tenant info, SKU/license queries, user lookups |
| `AuditLog.Read.All` | UAL access |
| `User.Read.All` | Group/role membership queries |
| `RoleManagement.Read.Directory` | Role assignment detection + PIM eligibility queries |
| `Policy.Read.All` | CA policies and Security Defaults — **not** covered by Directory.Read.All |
| `Reports.Read.All` | Copilot usage summary endpoint — held by Reports Reader, Security Reader, Global Reader, Compliance Admin, Global Admin |

---

## 7. OPERATIONS MATRIX

```
[1] AUDITOR MODE    Forensic Health Check
                    UAL status and retention (threshold-evaluated, not just displayed)
                    Entra ID diagnostic logging (category validation, not just existence)
                    Azure Activity Log export (current subscription)
                    Mailbox auditing and retention
                    External auto-forwarding policy (BEC exfiltration gate)
                    Copilot AI telemetry (UAL capture, Purview tier, email access logging)

[2] PROTECTOR MODE  Identity & Posture Check
                    Security Defaults status
                    Conditional Access policies (Enabled / Disabled / Report-only)
                    CA policy MFA grant coverage (BuiltInControls:mfa + AuthenticationStrength)
                    MFA enforcement correlation (Security Defaults + CA cross-check)
                    Legacy authentication block detection
                    PIM standing Global Administrator access
                    Security service plan inventory (HashSet O(1) lookups)
                    Copilot data governance (MIP licensing + MFA enforcement correlation)

[3] LICENSOR MODE   Defensive Stack & License Inventory
                    Defender suite and Sentinel deployment status (deduplicated)
                    Full SKU inventory with over-consumption detection
                    Copilot license analysis (seat utilization, expiry warnings, usage summary)

[4] SUPER AUDITOR   Runs Modes 1 + 2 + 3 sequentially
                    Generates executive HTML report with:
                    - Key Findings panel (critical items at a glance)
                    - Collapsible sections with chevron toggle
                    - Sticky top navigation (jump to any section)
                    - Row-level severity highlighting (critical/warning tints)
                    - Zebra row striping
                    - Healthy count alongside Critical/Warning in stats
                    - Section 5: Consolidated Copilot AI Audit

[5] ACTIVATOR MODE  Remediation — Enable Unified Audit Logging
                    Requires Global Administrator OR Compliance Administrator
                    Requires 'ENABLE-UAL' confirmation string
                    All actions logged to operator audit trail
```

---

## 8. COPILOT AI AUDIT INTEGRATION

Copilot audit checks are embedded directly into each mode rather than a separate option,
so every standard audit run automatically includes AI governance visibility.

| Mode | Copilot checks |
|------|----------------|
| Auditor [1] | UAL `CopilotInteraction` event capture (30-day probe); Purview Audit tier (Standard 90d vs Premium 1yr); Mailbox audit cross-check for Copilot email access logging |
| Protector [2] | MIP sensitivity label licensing; Copilot + MFA enforcement correlation (CRITICAL if Copilot licensed with zero MFA enforcement) |
| Licensor [3] | Copilot SKU and bundled service plan detection; seat utilization and expiry warnings; Copilot usage summary via Graph Reports API |
| Super Auditor [4] | HTML Section 5 consolidates all Copilot findings from the three modes into one panel |

**Why these checks matter:** A threat actor using a compromised account with Copilot access
can summarise inboxes, search SharePoint, and retrieve Teams messages at scale — silently,
if UAL is off or if Copilot email access logging (MailItemsAccessed) is not captured.

---

## 9. CLOUD IR PREPAREDNESS & SECURITY PILLARS

### Unified Audit Log (UAL)
Verifies UAL ingestion is enabled. Without it, there is zero visibility into M365 file,
email, and admin activity. Retention is evaluated against a 90-day threshold — not just
displayed as a raw value.

### Entra ID Diagnostic Logging
Checks whether `SignInLogs` and `AuditLogs` categories are both enabled in a diagnostic
setting on the Entra ID endpoint. Existence of a setting is insufficient — the tool validates
the categories. Requires Az.Monitor and Monitoring Reader Azure role.

### Azure Activity Log Export
Validates whether the current subscription has a diagnostic setting exporting activity logs
beyond the 90-day default. Scoped to the active subscription context.

### Mailbox Auditing
Confirms org-level mailbox auditing is enabled. Retention is threshold-evaluated.
Cross-referenced with external auto-forwarding to present a complete BEC picture.

### External Auto-Forwarding
Checks `Get-RemoteDomain -Identity Default` for `AutoForwardEnabled`. If allowed at org
level, BEC actors can silently forward all mail to an external attacker-controlled inbox.

### Conditional Access & MFA Enforcement
CA policies are inspected for actual state (enforced / report-only / disabled), not just
counted. A separate MFA grant coverage count identifies how many enforced policies
explicitly require MFA via `BuiltInControls` or `AuthenticationStrength`.

### Legacy Authentication Block
Inspects CA policies for blocks on `exchangeActiveSync` and `other` client types.
Legacy auth bypasses MFA and is the entry point for password spray attacks.

### PIM Standing Access
Detects permanent Global Administrator assignments with no PIM eligibility schedule,
flagging tenants where GA access is always-on rather than time-bound.

### Microsoft 365 Copilot AI Governance
See Section 8 above.

---

## 10. HTML EXECUTIVE REPORT

Generated by Super Auditor [4]. Dark-themed, responsive, browser-ready.

**Features:**
- Sticky top navigation bar with per-section jump links
- Key Findings panel — critical items extracted and listed before the tables
- Collapsible sections (click header to expand/collapse, chevron indicator)
- Row-level severity: critical rows have a red left border + tint; warning rows amber
- Zebra row striping on all tables
- Stats card: Total Checks, Critical count, Warning count, Healthy count
- Section 5: Consolidated Copilot AI Audit (sub-tables for telemetry, governance, licensing)
- Print CSS: sections expand, nav hidden, headers un-sticky

**Saved to:**
```
Downloads/MAT_Reports/<TenantName>/YYYY-MM-DD/MAT_Executive_Report_YYYYMMDD_HHMMSS.html
```

---

## 11. OUTPUTS

All outputs saved to `Downloads/MAT_Reports/` (Windows) or `~/Downloads/MAT_Reports/` (macOS).

| File | Created by |
|------|-----------|
| `Auditor_Report.csv` | Auditor mode [1] and Super Auditor [4] |
| `Protector_Inventory.csv` | Protector mode [2] and Super Auditor [4] |
| `Defensive_Stack.csv` | Licensor mode [3] and Super Auditor [4] |
| `Licenses_Inventory.csv` | Licensor mode [3] and Super Auditor [4] |
| `MAT_Executive_Report_*.html` | Super Auditor [4] only |
| `MAT_Operational_Logs/*_OA.txt` | Every mode run (non-repudiation audit trail) |

---

## 12. REFERENCES

- Microsoft SKU & Service Plan Reference:
  https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference

- Microsoft Incident Response — M365 Forensic Artifacts:
  https://go.microsoft.com/fwlink/?linkid=2257423

- Microsoft 365 License Matrix:
  https://m365maps.com/matrix.htm

- Purview Audit (Copilot — CopilotInteraction record type):
  https://learn.microsoft.com/en-us/purview/audit-copilot

- Purview Audit Premium (M365_ADVANCED_AUDITING):
  https://learn.microsoft.com/en-us/purview/audit-premium

- Monitoring Reader role (required for Entra diagnostic endpoint):
  https://learn.microsoft.com/en-us/azure/azure-monitor/roles-permissions-security

- PIM role activation:
  https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-how-to-activate-role

---
