# Command Reference

Auto-generated help for all SqlLabDataGenerator exported commands.
Generated with [Microsoft.PowerShell.PlatyPS](https://github.com/PowerShell/platyPS) v1.0.

To regenerate updated help from source:

```powershell
Install-Module Microsoft.PowerShell.PlatyPS -Scope CurrentUser
Import-Module SqlLabDataGenerator
$mod = Get-Module SqlLabDataGenerator
New-MarkdownCommandHelp -ModuleInfo $mod -OutputFolder ./docs/commands -Force -WithModulePage
```

---

## Module

- [SqlLabDataGenerator](SqlLabDataGenerator.md)

## Connection

- [Connect-SldgDatabase](Connect-SldgDatabase.md)
- [Disconnect-SldgDatabase](Disconnect-SldgDatabase.md)

## AI

- [Set-SldgAIProvider](Set-SldgAIProvider.md)
- [Get-SldgAIProvider](Get-SldgAIProvider.md)
- [Test-SldgAIProvider](Test-SldgAIProvider.md)

## Prompt Management

- [Get-SldgPromptTemplate](Get-SldgPromptTemplate.md)
- [Set-SldgPromptTemplate](Set-SldgPromptTemplate.md)
- [Remove-SldgPromptTemplate](Remove-SldgPromptTemplate.md)

## Schema & Analysis

- [Get-SldgDatabaseSchema](Get-SldgDatabaseSchema.md)
- [Get-SldgColumnAnalysis](Get-SldgColumnAnalysis.md)

## Generation

- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)
- [Set-SldgGenerationRule](Set-SldgGenerationRule.md)
- [Invoke-SldgDataGeneration](Invoke-SldgDataGeneration.md)
- [Test-SldgGeneratedData](Test-SldgGeneratedData.md)

## Profile

- [Export-SldgGenerationProfile](Export-SldgGenerationProfile.md)
- [Import-SldgGenerationProfile](Import-SldgGenerationProfile.md)

## Locale

- [Register-SldgLocale](Register-SldgLocale.md)

## Transform

- [Export-SldgTransformedData](Export-SldgTransformedData.md)
- [Get-SldgTransformer](Get-SldgTransformer.md)
- [Register-SldgTransformer](Register-SldgTransformer.md)
