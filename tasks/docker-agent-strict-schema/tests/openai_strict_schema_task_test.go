package openai

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func objectWithProperty(property map[string]any) map[string]any {
	return map[string]any{
		"type":                 "object",
		"additionalProperties": false,
		"properties":           map[string]any{"value": property},
		"required":             []any{"value"},
	}
}

func checkStrictCompatibilityRejectsUnsupportedKeywords(t *testing.T) {
	keywords := []string{"oneOf", "allOf", "not", "if", "then", "else", "dependentRequired", "dependentSchemas"}
	for _, keyword := range keywords {
		t.Run(keyword, func(t *testing.T) {
			var value any = map[string]any{"type": "string"}
			if keyword == "oneOf" || keyword == "allOf" {
				value = []any{map[string]any{"type": "string"}}
			}
			schema := objectWithProperty(map[string]any{keyword: value})
			_, strict, err := ConvertParametersToSchema(schema)
			require.NoError(t, err)
			assert.False(t, strict, "%s is not supported in strict mode", keyword)
		})
	}
}

func checkStrictCompatibilityTraversesSchemaContainers(t *testing.T) {
	bad := map[string]any{"type": "object", "additionalProperties": true}
	cases := map[string]map[string]any{
		"defs":              {"$defs": map[string]any{"bad": bad}},
		"definitions":       {"definitions": map[string]any{"bad": bad}},
		"patternProperties": {"patternProperties": map[string]any{".*": bad}},
		"contains":          {"contains": bad},
		"propertyNames":     {"propertyNames": bad},
	}
	for name, child := range cases {
		t.Run(name, func(t *testing.T) {
			schema := map[string]any{"type": "object", "additionalProperties": false, "properties": map[string]any{}}
			for key, value := range child {
				schema[key] = value
			}
			_, strict, err := ConvertParametersToSchema(schema)
			require.NoError(t, err)
			assert.False(t, strict)
		})
	}
}

func checkStrictCompatibilityValidatesReferences(t *testing.T) {
	base := func(ref any, siblings map[string]any) map[string]any {
		refNode := map[string]any{"$ref": ref}
		for key, value := range siblings {
			refNode[key] = value
		}
		return map[string]any{
			"type":                 "object",
			"additionalProperties": false,
			"properties":           map[string]any{"item": refNode},
			"required":             []any{"item"},
			"$defs":                map[string]any{"thing": map[string]any{"type": "string"}},
		}
	}
	cases := []struct {
		name string
		ref  any
		sib  map[string]any
	}{
		{"remote", "https://example.invalid/schema.json", nil},
		{"dangling", "#/$defs/missing", nil},
		{"non-string", 42, nil},
		{"sibling", "#/$defs/thing", map[string]any{"description": "item"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, strict, err := ConvertParametersToSchema(base(tc.ref, tc.sib))
			require.NoError(t, err)
			assert.False(t, strict)
		})
	}
}

func checkConversionPreservesReferenceSemantics(t *testing.T) {
	schema := map[string]any{
		"type":                 "object",
		"additionalProperties": false,
		"properties": map[string]any{
			"requiredRef": map[string]any{"$ref": "#/$defs/a~1b~0c"},
			"optionalRef": map[string]any{"$ref": "#/$defs/a~1b~0c"},
		},
		"required": []any{"requiredRef"},
		"$defs":    map[string]any{"a/b~c": map[string]any{"type": "string"}},
	}
	result, strict, err := ConvertParametersToSchema(schema)
	require.NoError(t, err)
	require.True(t, strict)
	properties := result["properties"].(map[string]any)
	assert.Equal(t, map[string]any{"$ref": "#/$defs/a~1b~0c"}, properties["requiredRef"])
	optional := properties["optionalRef"].(map[string]any)
	assert.NotContains(t, optional, "type")
	assert.Equal(t, []any{
		map[string]any{"$ref": "#/$defs/a~1b~0c"},
		map[string]any{"type": "null"},
	}, optional["anyOf"])
}

// The private scoring contract fails an attempt when at least half of its
// FAIL_TO_PASS assertions remain. Keep the OpenAI-side requirements under one
// top-level assertion so fixing only a large, easy subgroup cannot outweigh an
// omitted reference or normalization requirement.
func TestTaskOpenAIRequiredStrictSchemaBehavior(t *testing.T) {
	t.Run("unsupported_keywords", checkStrictCompatibilityRejectsUnsupportedKeywords)
	t.Run("schema_containers", checkStrictCompatibilityTraversesSchemaContainers)
	t.Run("references", checkStrictCompatibilityValidatesReferences)
	t.Run("reference_normalization", checkConversionPreservesReferenceSemantics)
}

func TestTaskStrictCompatibilityKeepsSupportedAnyOf(t *testing.T) {
	schema := objectWithProperty(map[string]any{"anyOf": []any{
		map[string]any{"type": "string"},
		map[string]any{"type": "null"},
	}})
	result, strict, err := ConvertParametersToSchema(schema)
	require.NoError(t, err)
	assert.True(t, strict)
	value := result["properties"].(map[string]any)["value"].(map[string]any)
	assert.Len(t, value["anyOf"], 2)
}

func TestTaskConversionTerminatesForSelfReference(t *testing.T) {
	schema := map[string]any{
		"type":                 "object",
		"additionalProperties": false,
		"properties":           map[string]any{"root": map[string]any{"$ref": "#/$defs/node"}},
		"required":             []any{"root"},
		"$defs": map[string]any{
			"node": map[string]any{
				"type":                 "object",
				"additionalProperties": false,
				"properties":           map[string]any{"next": map[string]any{"$ref": "#/$defs/node"}},
				"required":             []any{"next"},
			},
		},
	}
	_, strict, err := ConvertParametersToSchema(schema)
	require.NoError(t, err)
	assert.True(t, strict)
}

func TestTaskConversionPreservesOrdinarySchemas(t *testing.T) {
	schema := objectWithProperty(map[string]any{"type": "string", "format": "uri"})
	result, strict, err := ConvertParametersToSchema(schema)
	require.NoError(t, err)
	assert.True(t, strict)
	value := result["properties"].(map[string]any)["value"].(map[string]any)
	assert.Equal(t, "string", value["type"])
	assert.NotContains(t, value, "format")
}
