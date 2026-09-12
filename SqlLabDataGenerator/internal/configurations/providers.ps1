<#
Built-in schema/data function maps and transformers.
Loaded after configuration.ps1 (alphabetical order) so $script:SldgState is already initialized.

Connections themselves are opened through PSSqlRepository (Connect-SldgRepositorySession);
the registrations live in Register-SldgBuiltInProvider so Reset-SldgSession can restore
them after SldgSession.Reset() has cleared the registries.
#>
Register-SldgBuiltInProvider
