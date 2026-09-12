---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: en-US
Module Name: SqlLabDataGenerator
ms.date: 09/12/2026
PlatyPS schema version: 2024-05-01
title: Set-SldgAIProvider
---

# Set-SldgAIProvider

## SYNOPSIS

Configures the AI provider for semantic analysis and data generation.

## SYNTAX

### __AllParameterSets

```
Set-SldgAIProvider [-Provider] <string> [[-Model] <string>] [[-Endpoint] <string>]
 [[-ApiKey] <securestring>] [[-Credential] <pscredential>] [[-MaxTokens] <int>]
 [[-Temperature] <double>] [[-Locale] <string>] [[-Purpose] <string>] [-EnableAIGeneration]
 [-EnableAILocale] [-SkipCertificateCheck] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

One-command setup for the AI backend.
Configures which AI provider to use
(Ollama, OpenAI, or AzureOpenAI), the model, endpoint, and generation features.

For Ollama, no API key is required — just specify the model name and optionally
the endpoint (defaults to http://localhost:11434).

Optionally enables AI-powered data generation and AI-powered locale generation.

Use -Purpose to configure a different AI model for a specific task.
This allows
combining models — e.g.
GPT-4 for column analysis but a local Ollama model
for structured JSON/XML generation.

## EXAMPLES

### EXAMPLE 1

Set-SldgAIProvider -Provider Ollama -Model 'llama3'

Configures Ollama with llama3 model on default localhost endpoint.

### EXAMPLE 2

Set-SldgAIProvider -Provider Ollama -Model 'my-custom-model' -Endpoint 'http://gpu-server:11434' -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'

Configures a custom Ollama model on a remote server with full AI features and Czech locale.

### EXAMPLE 3

Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key -EnableAIGeneration

Configures OpenAI GPT-4o with AI data generation enabled.

### EXAMPLE 4

Set-SldgAIProvider -Provider AzureOpenAI -Model 'gpt-4' -Endpoint 'https://myinstance.openai.azure.com' -ApiKey $key

Configures Azure OpenAI.

### EXAMPLE 5

Set-SldgAIProvider -Provider None

Disables AI entirely.
Falls back to pattern matching and static generators.

### EXAMPLE 6

Set-SldgAIProvider -Provider Ollama -Model 'codellama' -Purpose 'structured-value'

Uses Ollama codellama specifically for JSON/XML structured value generation,
while other AI tasks use the global provider.

### EXAMPLE 7

Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key
PS C:\> Set-SldgAIProvider -Provider Ollama -Model 'llama3' -Endpoint 'http://gpu:11434' -Purpose 'batch-generation'

Global: GPT-4o for classification and planning.
Override: Ollama for batch data generation.

## PARAMETERS

### -ApiKey

API key for the provider.
Required for OpenAI and AzureOpenAI.
Not needed for Ollama.

```yaml
Type: System.Security.SecureString
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
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

### -Credential

PSCredential object whose password is used as the API key.
Alternative to -ApiKey.

```yaml
Type: System.Management.Automation.PSCredential
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -EnableAIGeneration

Enable AI-powered data generation.
AI generates entire rows of contextually-consistent data.

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

### -EnableAILocale

Enable AI-powered locale generation.
AI creates locale data on-the-fly for any language.

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

### -Endpoint

The API endpoint URL.
- Ollama: defaults to http://localhost:11434 if not specified
- AzureOpenAI: required (e.g., https://myinstance.openai.azure.com)
- OpenAI: not needed (uses api.openai.com)

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Locale

Set the default locale for data generation (e.g., 'cs-CZ', 'de-DE').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 7
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MaxTokens

Maximum tokens for AI responses.
Default: 4096.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Model

The model name (e.g., 'llama3', 'mistral', 'codellama', 'gpt-4', 'gpt-4o').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Provider

The AI provider: Ollama, OpenAI, AzureOpenAI, or None (to disable AI).

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Purpose

Set a per-purpose AI model override instead of the global default.
Valid purposes:
column-analysis, batch-generation, plan-advice, schema-analysis, structured-value,
locale-data, locale-category.
When AI runs for that purpose, the override is used instead of the global config.

Two-tier AI setup example: use a smart cloud model for schema-analysis and a fast
local model for batch-generation:
  Set-SldgAIProvider -Provider OpenAI -Model 'o3' -ApiKey $key
  Set-SldgAIProvider -Provider Ollama -Model 'llama3' -Purpose batch-generation

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 8
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SkipCertificateCheck

Skip TLS certificate validation (for self-signed certs on Ollama dev servers).

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

### -Temperature

Temperature for Ollama responses (0.0 = deterministic, 1.0 = creative).
Default: 0.3.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 6
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### SqlLabDataGenerator.AIProviderInfo

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

