package tools

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestTaskSchemaToMapLeavesReferencesUntouched(t *testing.T) {
	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"direct": map[string]any{"$ref": "#/$defs/thing"},
			"nested": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"value": map[string]any{"$ref": "#/$defs/thing"},
				},
			},
		},
		"$defs": map[string]any{"thing": map[string]any{"type": "string"}},
	}
	result, err := SchemaToMap(schema)
	require.NoError(t, err)
	properties := result["properties"].(map[string]any)
	assert.Equal(t, map[string]any{"$ref": "#/$defs/thing"}, properties["direct"])
	nested := properties["nested"].(map[string]any)["properties"].(map[string]any)
	assert.Equal(t, map[string]any{"$ref": "#/$defs/thing"}, nested["value"])
}
