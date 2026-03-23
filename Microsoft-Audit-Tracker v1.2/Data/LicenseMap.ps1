# ================================================================================
# DATA: LicenseMap.ps1
# Description: Authoritative SKU and Defender service-plan mappings for MAT.
#              All modules reference $script:LicenseSkuMap, $script:LicenseDefenderMap,
#              and $script:CopilotServicePlans instead of defining local copies.
# v1.2: Added Copilot SKU part numbers and CopilotServicePlans array.
# ================================================================================

$script:LicenseSkuMap = @{
    # Office 365 Enterprise
    "STANDARDPACK"                    = "Office 365 E1"
    "ENTERPRISEPACK"                  = "Office 365 E3"
    "ENTERPRISEPREMIUM"               = "Office 365 E5"
    "ENTERPRISEWITHSCAL"              = "Office 365 E4 (Legacy)"
    "MIDSIZEPACK"                     = "Office 365 Midsize Business (Legacy)"
    # Microsoft 365 Enterprise
    "SPE_E3"                          = "Microsoft 365 E3"
    "SPE_E5"                          = "Microsoft 365 E5 (Full)"
    "SPE_F1"                          = "Microsoft 365 F1 (Legacy)"
    "M365_E3"                         = "Microsoft 365 E3"
    "M365_E5"                         = "Microsoft 365 E5"
    "M365_E5_SECURITY"                = "Microsoft 365 E5 Security"
    "M365_E5_COMPLIANCE"              = "Microsoft 365 E5 Compliance"
    "IDENTITY_THREAT_PROTECTION"      = "Microsoft 365 E5 Security (Legacy)"
    "THREAT_INTELLIGENCE"             = "Microsoft 365 E5 Security Add-on"
    # Microsoft 365 Business
    "M365_BUSINESS_BASIC"             = "Microsoft 365 Business Basic"
    "M365_BUSINESS_STANDARD"          = "Microsoft 365 Business Standard"
    "M365_BUSINESS_PREMIUM"           = "Microsoft 365 Business Premium"
    "O365_BUSINESS"                   = "Office 365 Business"
    "O365_BUSINESS_ESSENTIALS"        = "Office 365 Business Essentials"
    "O365_BUSINESS_PREMIUM"           = "Office 365 Business Premium"
    "SPB"                             = "Microsoft 365 Business Premium"
    # Frontline
    "M365_F1"                         = "Microsoft 365 F1"
    "M365_F3"                         = "Microsoft 365 F3"
    "DESKLESSPACK"                    = "Office 365 F3"
    "M365_F5_SECURITY"                = "Microsoft 365 F5 Security"
    "M365_F5_COMPLIANCE"              = "Microsoft 365 F5 Compliance"
    "M365_F5_SECCOMP"                 = "Microsoft 365 F5 Security + Compliance"
    # Education
    "M365_A1"                         = "Microsoft 365 A1 (Legacy)"
    "A1_FOR_DEVICES"                  = "Microsoft 365 A1 for Devices"
    "M365_A3"                         = "Microsoft 365 A3"
    "M365EDU_A3"                      = "Microsoft 365 A3"
    "M365_A5"                         = "Microsoft 365 A5 (Full)"
    "M365EDU_A5"                      = "Microsoft 365 A5"
    "M365_A5_SECURITY"                = "Microsoft 365 A5 Security"
    "M365_A5_COMPLIANCE"              = "Microsoft 365 A5 Compliance"
    "STANDARDWOFFPACK_IW_STUDENT"     = "Office 365 A1 Student"
    "STANDARDWOFFPACK_IW_FACULTY"     = "Office 365 A1 Faculty"
    # Defender / Security Add-ons
    "ATP_ENTERPRISE"                  = "Defender for Office 365 Plan 2"
    "ATP_ENTERPRISE_FACULTY"          = "Defender for Office 365 Plan 2 (Faculty)"
    "ATP_ENTERPRISE_STUDENT"          = "Defender for Office 365 Plan 2 (Student)"
    "AAD_PREMIUM"                     = "Azure AD Premium P1"
    "AAD_PREMIUM_P2"                  = "Azure AD Premium P2"
    "EMS"                             = "Enterprise Mobility + Security E3"
    "EMSPREMIUM"                      = "Enterprise Mobility + Security E5"
    # Microsoft 365 Copilot — standalone and add-on SKU part numbers
    # Multiple variants exist across markets and licensing waves — all mapped here.
    "Microsoft_365_Copilot"           = "Microsoft 365 Copilot"
    "COPILOT_FOR_M365"                = "Microsoft 365 Copilot"
    "M365_COPILOT"                    = "Microsoft 365 Copilot"
    "COPILOT_FOR_MICROSOFT_365"       = "Microsoft 365 Copilot"
    # Government
    "ENTERPRISEPACK_GOV"              = "Office 365 E3 (GCC)"
    "ENTERPRISEPREMIUM_GOV"           = "Office 365 E5 (GCC)"
    "SPE_E3_GOV"                      = "Microsoft 365 E3 (GCC)"
    "SPE_E5_GOV"                      = "Microsoft 365 E5 (GCC)"
    "ENTERPRISEPACK_GOV_HI"           = "Office 365 E3 (GCC High)"
    "ENTERPRISEPREMIUM_GOV_HI"        = "Office 365 E5 (GCC High)"
    "DOD_ENTERPRISEPACK"              = "Office 365 E3 (DoD)"
    "DOD_ENTERPRISEPREMIUM"           = "Office 365 E5 (DoD)"
    # Misc
    "FLOW_FREE"                       = "Power Automate Free"
    "POWER_BI_STANDARD"               = "Power BI Pro"
    "POWER_BI_PREMIUM"                = "Power BI Premium"
    "PROJECTPROFESSIONAL"             = "Project Plan 3"
    "PROJECTPREMIUM"                  = "Project Plan 5"
    "VISIOCLIENT"                     = "Visio Plan 2"
}

$script:LicenseDefenderMap = @{
    # Sentinel
    "*SENTINEL*"                                      = "Microsoft Sentinel"
    "MICROSOFT_SENTINEL"                              = "Microsoft Sentinel"
    "AZURE_SENTINEL"                                  = "Microsoft Sentinel"
    # Endpoint
    "THREAT_PROTECTION"                               = "Defender for Endpoint"
    "WINDOWS_DEFENDER_ADVANCED_THREAT_PROTECTION"     = "Defender for Endpoint"
    "MDATP"                                           = "Defender for Endpoint"
    "MDE_PLAN2"                                       = "Defender for Endpoint Plan 2"
    "MDE_PLAN1"                                       = "Defender for Endpoint Plan 1"
    # Office 365
    "ATP_ENTERPRISE"                                  = "Defender for Office 365 Plan 2"
    "ATP_ENTERPRISE_FACULTY"                          = "Defender for Office 365 Plan 2"
    "ATP_ENTERPRISE_STUDENT"                          = "Defender for Office 365 Plan 2"
    "EXCHANGE_ADVANCED_THREAT_PROTECTION"             = "Defender for Office 365 Plan 1"
    "ATP_STANDARD"                                    = "Defender for Office 365 Plan 1"
    # Identity
    "AZURE_ACTIVE_DIRECTORY_PLATFORM"                 = "Defender for Identity"
    "AAD_IDENTITY_PROTECTION"                         = "Defender for Identity"
    "M365_DEFENDER_IDENTITY"                          = "Defender for Identity"
    # Cloud Apps
    "CLOUDAPPSECURITY"                                = "Defender for Cloud Apps"
    "MICROSOFT_CLOUD_APP_SECURITY"                    = "Defender for Cloud Apps"
    "MCAS"                                            = "Defender for Cloud Apps"
    # XDR / IoT
    "MTP"                                             = "Defender XDR"
    "MICROSOFT_THREAT_PROTECTION"                     = "Defender XDR"
    "M365_DEFENDER"                                   = "Defender XDR"
    "*IOT*"                                           = "Defender for IoT"
    "IOT_SECURITY"                                    = "Defender for IoT"
}

# Copilot service plan names as they appear inside bundle SKUs (e.g. E5 + Copilot add-on).
# Used by Licensor and Protector for bundle detection when no standalone Copilot SKU is present.
$script:CopilotServicePlans = @(
    "Copilot_for_M365",
    "Microsoft_365_Copilot",
    "M365_COPILOT",
    "COPILOT_FOR_MICROSOFT_365"
)

Write-Verbose "LicenseMap loaded: $($script:LicenseSkuMap.Count) SKUs, $($script:LicenseDefenderMap.Count) Defender plans, $($script:CopilotServicePlans.Count) Copilot service plans"
