---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Export-SldgTransformedData
---

# Export-SldgTransformedData

## SYNOPSIS

Transforms generated data into a target format (e.g., Entra ID users, Entra ID groups).

## SYNTAX

### __AllParameterSets

```
Export-SldgTransformedData [-Data] <DataTable> [-Transformer] <string> [[-OutputPath] <string>]
 [[-ColumnMapping] <hashtable>] [[-TransformerParams] <hashtable>] [<CommonParameters>]
```

## DESCRIPTION

Takes generated data (DataTable from Invoke-SldgDataGeneration with -PassThru)
and transforms it using a registered transformer.
Supports output to JSON files
for import into target systems, or returns objects for pipeline use.

Built-in transformers:
- EntraIdUser: Microsoft Entra ID (Azure AD) user objects for Microsoft Graph API
- EntraIdGroup: Microsoft Entra ID group objects for Microsoft Graph API

## EXAMPLES

### EXAMPLE 1

$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru
PS C:\> $users = Export-SldgTransformedData -Data $result.Tables[0].DataTable -Transformer 'EntraIdUser' -TransformerParams @{ Domain = 'mycompany.onmicrosoft.com' }

Transforms the first table's data into Entra ID user objects.

### EXAMPLE 2

Export-SldgTransformedData -Data $data -Transformer 'EntraIdUser' -OutputPath 'C:\export\users.json'

Exports transformed user data to a JSON file.

### EXAMPLE 3

$groups = Export-SldgTransformedData -Data $deptData -Transformer 'EntraIdGroup' -TransformerParams @{ GroupType = 'Microsoft365' }

Creates Microsoft 365 group objects from department data.

## PARAMETERS

### -ColumnMapping

Optional hashtable mapping target properties to source column names.
If not specified, auto-detection is used based on column name patterns.

```yaml
Type: System.Collections.Hashtable
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

### -Data

The DataTable containing generated data (from generation result with -PassThru).

```yaml
Type: System.Data.DataTable
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

### -OutputPath

Optional file path to save the transformed data as JSON.

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

### -Transformer

Name of the registered transformer to use.

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

### -TransformerParams

Optional hashtable of additional parameters to pass to the transformer function.

```yaml
Type: System.Collections.Hashtable
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
- [Register-SldgTransformer](Register-SldgTransformer.md)
- [Invoke-SldgDataGeneration](Invoke-SldgDataGeneration.md)