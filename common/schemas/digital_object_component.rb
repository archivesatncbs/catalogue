# Schema inherits from the abstract_archival_object schema, and must only include extensions/overrides unique to digital object component records.

{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "parent" => "abstract_archival_object",
    "uri" => "/repositories/:repo_id/digital_object_components",
    "properties" => {

      "component_id" => {"type" => "string", "maxLength" => 255},
      "label" => {"type" => "string", "maxLength" => 255},
      "title" => {"type" => "string", "ifmissing" => nil},
      "display_string" => {"type" => "string", "maxLength" => 8192, "readonly" => true},

      "file_versions" => {"type" => "array", "items" => {"type" => "JSONModel(:file_version) object"}},

      "slug" => {"type" => "string"},
      "is_slug_auto" => {"type" => "boolean", "default" => true},

      "parent" => {
        "type" => "object",
        "subtype" => "ref",
        "properties" => {
          "ref" => {"type" => "JSONModel(:digital_object_component) uri"},
          "_resolved" => {
            "type" => "object",
            "readonly" => "true"
          }
        }
      },

      "digital_object" => {
        "type" => "object",
        "subtype" => "ref",
        "properties" => {
          "ref" => {"type" => "JSONModel(:digital_object) uri"},
          "_resolved" => {
            "type" => "object",
            "readonly" => "true"
          }
        },
        "ifmissing" => "error"
      },

      "position" => {"type" => "integer", "required" => false},

      "notes" => {
            "type" => "array",
            "items" => {"type" => [{"type" => "JSONModel(:note_bibliography) object"},
                                   {"type" => "JSONModel(:note_digital_object) object"}]},
          },

      "has_unpublished_ancestor" => {"type" => "boolean", "readonly" => "true"},

      "ancestors" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "subtype" => "ref",
          "properties" => {
            "ref" => {"type" => [{"type" => "JSONModel(:digital_object) uri"},
                                 {"type" => "JSONModel(:digital_object_component) uri"}]},
            "_resolved" => {
              "type" => "object",
              "readonly" => "true"
            }
          }
        }
      },
    },
  },
}
