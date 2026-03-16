# Provider completers
Register-PSFTeppArgumentCompleter -Command Connect-SldgDatabase -Parameter Provider -Name SqlLabDataGenerator.Provider

# Mode completers
Register-PSFTeppArgumentCompleter -Command New-SldgGenerationPlan -Parameter Mode -Name SqlLabDataGenerator.GenerationMode

# Semantic type completers
Register-PSFTeppArgumentCompleter -Command Set-SldgGenerationRule -Parameter Generator -Name SqlLabDataGenerator.SemanticType

# Industry hint completers
Register-PSFTeppArgumentCompleter -Command Get-SldgColumnAnalysis -Parameter IndustryHint -Name SqlLabDataGenerator.Industry

# Transformer completers
Register-PSFTeppArgumentCompleter -Command Export-SldgTransformedData -Parameter Transformer -Name SqlLabDataGenerator.Transformer
Register-PSFTeppArgumentCompleter -Command Get-SldgTransformer -Parameter Name -Name SqlLabDataGenerator.Transformer