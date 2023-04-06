{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "parent" => "abstract_note",

    "properties" => {

      "subnotes" => {
        "type" => "array",
        "items" => {"type" => [{"type" => "JSONModel(:note_text) object"},
                               {"type" => "JSONModel(:note_definedlist) object"},
                               {"type" => "JSONModel(:note_orderedlist) object"},
                               {"type" => "JSONModel(:note_outline) object"}]},
      },
    },
  },
}
