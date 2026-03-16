---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Register-SldgLocale
---

# Register-SldgLocale

## SYNOPSIS

Registers a locale data pack for data generation — manually or via AI.

## SYNTAX

### Manual (Default)

```
Register-SldgLocale -Name <string> -Data <hashtable> [-Force] [<CommonParameters>]
```

### AI

```
Register-SldgLocale -Name <string> -UseAI [-PoolSize <int>] [-CustomInstructions <string>] [-Force]
 [<CommonParameters>]
```

### Mix

```
Register-SldgLocale -Name <string> -MixFrom <hashtable> [-PoolSize <int>]
 [-CustomInstructions <string>] [-Force] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Registers a new locale with culture-specific data pools for generating
realistic localized data.
Three modes:

1.
Manual: Provide a hashtable with all required data keys.
2.
AI-generated: Use -UseAI to let AI generate the entire locale pack
   for any culture/language (requires configured AI provider).
3.
Mixed: Use -MixFrom to combine categories from different languages
   via AI (e.g., Czech names + German addresses).

Built-in locales: en-US, cs-CZ
AI can generate any locale on-the-fly (de-DE, fr-FR, ja-JP, ...).

## EXAMPLES

### EXAMPLE 1

Register-SldgLocale -Name 'de-DE' -UseAI

AI generates a complete German locale pack automatically.

### EXAMPLE 2

Register-SldgLocale -Name 'custom-mix' -MixFrom @{
>>     PersonNames = 'cs-CZ'
>>     Addresses   = 'de-DE'
>>     Companies   = 'en-US'
>>     PhoneFormat = 'cs-CZ'
>>     Text        = 'cs-CZ'
>> }

Creates a mixed locale: Czech names, German addresses, English companies.

### EXAMPLE 3

Register-SldgLocale -Name 'ja-JP' -UseAI -PoolSize 50 -CustomInstructions "Include both traditional and modern Japanese names"

AI generates Japanese locale with 50 items per pool and custom guidance.

### EXAMPLE 4

Register-SldgLocale -Name 'sk-SK' -Data @{
>>     MaleNames = @('Jan', 'Peter', 'Martin', ...)
>>     # ... all required keys
>> }

Manually registers a Slovak locale data pack.

## PARAMETERS

### -CustomInstructions

Additional instructions to pass to the AI for fine-tuning data generation
(e.g., "Focus on historical names from 18th century" or "Use only rural addresses").

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Mix
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: AI
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Data

A hashtable containing the locale data pools.
Required keys:
MaleNames, FemaleNames, LastNames, StreetNames, StreetTypes, Locations,
Countries, EmailDomains, PhoneFormat, CompanyPrefixes, CompanyCores,
CompanySuffixes, Departments, JobTitles, Industries.

```yaml
Type: System.Collections.Hashtable
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Manual
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Force

Overwrite an existing locale with the same name.
Also bypasses AI cache.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MixFrom

A hashtable mapping categories to language/culture codes for AI generation.
Enables mixing different languages per data category.
Valid categories: PersonNames, Addresses, PhoneFormat, Companies,
Identifiers, Email, Text.

```yaml
Type: System.Collections.Hashtable
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Mix
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Name

The locale identifier (e.g., 'de-DE', 'fr-FR', 'sk-SK').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PoolSize

Number of items per data pool when generating via AI.
Default: 30.

```yaml
Type: System.Int32
DefaultValue: 30
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Mix
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: AI
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -UseAI

Generate the locale data pack automatically via the configured AI provider.
Works with any language/culture code — no pre-built data pack needed.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: AI
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

- [Set-SldgAIProvider](Set-SldgAIProvider.md)
- [Invoke-SldgDataGeneration](Invoke-SldgDataGeneration.md)