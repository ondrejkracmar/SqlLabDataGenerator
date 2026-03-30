---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Register-SldgTransformer
---

# Register-SldgTransformer

## SYNOPSIS

Registers a custom data transformer.

## SYNTAX

### __AllParameterSets

```
Register-SldgTransformer [-Name] <string> [-Description] <string> [-TransformFunction] <string>
 [[-RequiredSemanticTypes] <string[]>] [[-OutputType] <string>] [<CommonParameters>]
```

## DESCRIPTION

Registers a custom transformer that converts generated DataTable data
into a specific target format.
The transformer function must accept
a -Data parameter (System.Data.DataTable) and return transformed objects.

## EXAMPLES

### EXAMPLE 1

Register-SldgTransformer -Name 'CsvUsers' `
>>     -Description 'Exports users as CSV-ready objects' `
>>     -TransformFunction 'ConvertTo-CsvUser'

## PARAMETERS

### -Description

Description of what the transformer produces.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Name

Unique name for the transformer.

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

### -OutputType

Optional type name of the output objects (e.g. `SqlLabDataGenerator.EntraIdUser`).

```yaml
Type: System.String
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

### -RequiredSemanticTypes

Optional list of semantic types the source data should contain.

```yaml
Type: System.String[]
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

### -TransformFunction

Name of the function that performs the transformation.
The function must accept a -Data [System.Data.DataTable] parameter.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
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

- [Get-SldgTransformer](Get-SldgTransformer.md)
- [Export-SldgTransformedData](Export-SldgTransformedData.md)