using System;
using Xunit;

namespace SqlLabDataGenerator.Tests
{
    public class DtoTests
    {
        [Fact]
        public void ColumnClassification_DefaultValues()
        {
            var classification = new ColumnClassification();

            Assert.Null(classification.ColumnName);
            Assert.Null(classification.SemanticType);
            Assert.False(classification.IsPII);
            Assert.Equal(0.0, classification.Confidence);
            Assert.Null(classification.Source);
        }

        [Fact]
        public void ColumnInfo_Classification_AcceptsTypedObject()
        {
            var col = new ColumnInfo
            {
                ColumnName = "Email",
                DataType = "nvarchar",
                Classification = new ColumnClassification
                {
                    ColumnName = "Email",
                    SemanticType = "Email",
                    IsPII = true,
                    Confidence = 0.95,
                    Source = "AI"
                }
            };

            Assert.NotNull(col.Classification);
            Assert.Equal("Email", col.Classification.SemanticType);
            Assert.True(col.Classification.IsPII);
        }

        [Fact]
        public void GenerationPlan_DefaultValues()
        {
            var plan = new GenerationPlan();

            Assert.Null(plan.Database);
            Assert.Null(plan.Mode);
            Assert.Null(plan.Tables);
            Assert.Equal(0, plan.TableCount);
            Assert.Equal(0, plan.TotalRows);
        }

        [Fact]
        public void TablePlan_DefaultValues()
        {
            var tablePlan = new TablePlan();

            Assert.Null(tablePlan.SchemaName);
            Assert.Null(tablePlan.TableName);
            Assert.Null(tablePlan.Columns);
            Assert.Null(tablePlan.ForeignKeys);
            Assert.False(tablePlan.HasCircularDependency);
        }

        [Fact]
        public void GenerationResult_DurationCalculation()
        {
            var result = new GenerationResult
            {
                StartedAt = new DateTime(2026, 1, 1, 10, 0, 0, DateTimeKind.Utc),
                CompletedAt = new DateTime(2026, 1, 1, 10, 5, 30, DateTimeKind.Utc),
                Duration = TimeSpan.FromMinutes(5.5)
            };

            Assert.Equal(5.5, result.Duration.TotalMinutes);
        }

        [Fact]
        public void AIModelOverride_Properties()
        {
            var ov = new AIModelOverride
            {
                Purpose = "batch-generation",
                Provider = "Ollama",
                Model = "llama3",
                Endpoint = "http://localhost:11434",
                MaxTokens = 2048
            };

            Assert.Equal("batch-generation", ov.Purpose);
            Assert.Equal("Ollama", ov.Provider);
            Assert.Equal(2048, ov.MaxTokens);
        }

        [Fact]
        public void SchemaModel_Properties()
        {
            var schema = new SchemaModel
            {
                Database = "TestDb",
                Tables = new[]
                {
                    new TableInfo { SchemaName = "dbo", TableName = "Users" }
                },
                DiscoveredAt = DateTime.UtcNow
            };

            Assert.Equal("TestDb", schema.Database);
            Assert.Single(schema.Tables);
        }

        [Fact]
        public void ValidationResult_Properties()
        {
            var result = new ValidationResult
            {
                CheckType = "ForeignKey",
                TableName = "Orders",
                Passed = false,
                Severity = "Error",
                Details = "Orphaned rows found"
            };

            Assert.False(result.Passed);
            Assert.Equal("Error", result.Severity);
        }

        [Fact]
        public void ForeignKeyInfo_Properties()
        {
            var fk = new ForeignKeyInfo
            {
                ForeignKeyName = "FK_Order_Customer",
                ParentSchema = "dbo",
                ParentTable = "Order",
                ParentColumn = "CustomerId",
                ReferencedSchema = "dbo",
                ReferencedTable = "Customer",
                ReferencedColumn = "Id"
            };

            Assert.Equal("FK_Order_Customer", fk.ForeignKeyName);
            Assert.Equal("Customer", fk.ReferencedTable);
        }

        [Fact]
        public void Transformer_Properties()
        {
            var t = new Transformer
            {
                Name = "EntraIdUser",
                Description = "Transforms to Entra ID user objects",
                TransformFunction = "ConvertTo-SldgEntraIdUser",
                RequiredSemanticTypes = new[] { "FirstName", "LastName", "Email" },
                OutputType = "SqlLabDataGenerator.EntraIdUser"
            };

            Assert.Equal(3, t.RequiredSemanticTypes.Length);
        }

        [Fact]
        public void RowSet_WithGeneratedValues()
        {
            var rowSet = new RowSet
            {
                RowCount = 100,
                GeneratedValues = new System.Collections.Hashtable
                {
                    ["dbo.Customer.Id"] = new[] { 1, 2, 3, 4, 5 }
                }
            };

            Assert.Equal(100, rowSet.RowCount);
            Assert.True(rowSet.GeneratedValues.ContainsKey("dbo.Customer.Id"));
        }
    }
}
