<#
    .SYNOPSIS
    LicenseMap.ps1 - License and Defender Service Plan Mappings
    .DESCRIPTION
    Global hashtables for translating Microsoft SKU part numbers and service plans
    into human-readable product names.
#>

# SKU Part Number to Product Name Mapping
$global:SkuMap = @{
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
    
    # Frontline
    "M365_F1"                         = "Microsoft 365 F1"
    "M365_F3"                         = "Microsoft 365 F3"
    "M365_F5_SECURITY"                = "Microsoft 365 F5 Security"
    "M365_F5_COMPLIANCE"              = "Microsoft 365 F5 Compliance"
    "M365_F5_SECCOMP"                 = "Microsoft 365 F5 Security + Compliance"
    
    # Education
    "M365_A1"                         = "Microsoft 365 A1 (Legacy)"
    "A1_FOR_DEVICES"                  = "Microsoft 365 A1 for Devices"
    "M365_A3"                         = "Microsoft 365 A3"
    "M365_A5"                         = "Microsoft 365 A5 (Full)"
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
    
    # Government SKUs
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

# Defender and Security Service Plan Mapping
$global:DefenderMap = @{
    # Microsoft Sentinel
    "MICROSOFT_SENTINEL*"             = "Microsoft Sentinel"
    "SENTINEL*"                       = "Microsoft Sentinel"
    
    # Defender for Endpoint
    "WINDEFATP"                       = "Defender for Endpoint"
    "DEFENDER_ENDPOINT*"              = "Defender for Endpoint"
    "MDE_SMB"                         = "Defender for Endpoint"
    "MDATP*"                          = "Defender for Endpoint"
    
    # Defender for Office 365
    "ATP_ENTERPRISE"                  = "Defender for Office 365"
    "THREAT_INTELLIGENCE"             = "Defender for Office 365"
    "EXCHANGE_S_FOUNDATION"           = "Defender for Office 365"
    "EOP_ENTERPRISE_PREMIUM"          = "Defender for Office 365"
    
    # Defender for Identity
    "ATA"                             = "Defender for Identity"
    "ADALLOM_STANDALONE"              = "Defender for Identity"
    "DEFENDER_FOR_IDENTITY*"          = "Defender for Identity"
    
    # Defender XDR (Unified)
    "M365_ADVANCED_AUDITING"          = "Defender XDR"
    "MICROSOFT_THREAT_PROTECTION"     = "Defender XDR"
    "MTP"                             = "Defender XDR"
    "M365D*"                          = "Defender XDR"
    
    # Defender for Cloud Apps (formerly MCAS)
    "ADALLOM_S_STANDALONE"            = "Defender for Cloud Apps"
    "CLOUD_APP_SECURITY*"             = "Defender for Cloud Apps"
    "MCAS*"                           = "Defender for Cloud Apps"
    "DEFENDER_CLOUD_APPS*"            = "Defender for Cloud Apps"
    
    # Defender for IoT
    "DEFENDER_FOR_IOT*"               = "Defender for IoT"
    "AZURE_DEFENDER_IOT*"             = "Defender for IoT"
    
    # Azure AD Premium / Identity Protection
    "AAD_PREMIUM"                     = "Azure AD Premium P1"
    "AAD_PREMIUM_P2"                  = "Azure AD Premium P2"
    "IDENTITY_THREAT_PROTECTION"      = "Azure AD Identity Protection"
    
    # Information Protection
    "INFORMATION_PROTECTION*"         = "Information Protection"
    "RIGHTSMANAGEMENT*"               = "Azure Information Protection"
    "AIP*"                            = "Azure Information Protection"
    
    # Compliance
    "COMPLIANCE*"                     = "Microsoft 365 Compliance"
    "INFORMATION_GOVERNANCE*"         = "Information Governance"
    "RECORDS_MANAGEMENT*"             = "Records Management"
}

Write-Host "[+] License and Defender maps loaded successfully" -ForegroundColor Green