require 'csv'

class Enumeration < Sequel::Model(:enumeration)

  include ASModel
  corresponds_to JSONModel(:enumeration)

  set_model_scope :global

  one_to_many :enumeration_value, :order => [ :position, :value ]

  @enumeration_dependants = {}

  CSV_HEADERS = ["Enumeration code", "Enumeration", "Value code", "Value", "Position", "Read-only"]

  # Record the fact that 'model' uses 'enum_name'.
  def self.register_enumeration_dependant(definition, model)
    Array(definition[:uses_enum]).each do |enum_name|
      @enumeration_dependants[enum_name] ||= []
      @enumeration_dependants[enum_name] << [definition, model]
    end
  end


  def self.dependants_of(enum_name)
    @enumeration_dependants[enum_name]
  end

  def dependants
    self.class.dependants_of(self.name) || []
  end

  # Find all database records that refer to the enumeration value identified by
  # 'source_id' and repoint them to 'destination_id'.
  def migrate(old_value, new_value)
    is_editable = ( self.editable === 1 or self.editable == true )
    if !is_editable
      raise EnumerationMigrationFailed.new("Can't migrate values for non-editable enumeration #{self.id}")
    end

    old_enum_value = self.enumeration_value.find {|val| val[:value] == old_value}

    if old_enum_value.nil?
      raise NotFoundException.new("Can't find a value '#{old_value}' in enumeration #{self.id}")
    end

    if old_enum_value.readonly != 0
      raise EnumerationMigrationFailed.new("Can't transfer from a read-only enumeration value")
    end

    new_enum_value = self.enumeration_value.find {|val| val[:value] == new_value}

    if new_enum_value.nil?
      raise NotFoundException.new("Can't find a value '#{new_value}' in enumeration #{self.id}")
    end

    dependants = self.class.dependants_of(self.name) ? self.class.dependants_of(self.name) : []
    dependants.each do |definition, model|
      property_id = "#{definition[:property]}_id".intern
      records = model.filter(property_id => old_enum_value.id)
      if model.included_modules.include?(ActiveAssociation)
        # update and check each record for a related record to reindex
        records.each do |rec|
          rec.update(property_id => new_enum_value.id, :system_mtime => Time.now)
          rec.broadcast_reindex
        end
      else
        # update in one go
        records.update(property_id => new_enum_value.id, :system_mtime => Time.now)
      end
    end

    old_enum_value.delete
    self.reload
    self.enumeration_value.each_with_index { |ev, i| ev.position = i; ev.save }
    self.class.broadcast_changes
  end


  # Update the allowable values of the current enumeration.
  def self.apply_values(obj, json, opts = {})
    # don't allow update of an non-editable enumeration
    # make sure the DB mapping has been converted.
    obj.reload
    is_editable = ( obj.editable === 1 or obj.editable == true )


    incoming_values = Array(json['values'])
    existing_values = obj.enumeration_value.select {|val| val[:suppressed] != 1 }.map {|val| val[:value] }
    # we need to keep suppressed values in mind for positioning
    existing_length = obj.enumeration_value.length

    added_values = incoming_values - existing_values
    removed_values = existing_values - incoming_values

    # if it's not editable, we cannot add or remove values, but we can set the
    # default...
    if (( !is_editable and added_values.length > 0 ) or ( !is_editable and removed_values.length > 0 )) and opts[:default_value].nil?
      raise AccessDeniedException.new("Cannot modify a non-editable enumeration: #{obj.name} with #{ json['values'].join(' , ') }. Only allowed values are : #{ obj.enumeration_value.join(' , ')} ")
    end

    # Make sure we're not being asked to remove read-only values.
    if EnumerationValue.filter(:enumeration_id => obj.id,
                               :value => removed_values,
                               :readonly => 1).count > 0

      raise AccessDeniedException.new("Can't remove read-only enumeration values")
    end


    added_values.each_with_index do |value, i|
      obj.add_enumeration_value(:value => value, :position => (existing_length + i + 1) )
    end

    removed_values.each do |value|
      DB.attempt {
        EnumerationValue.filter(:enumeration_id => obj.id,
                                :value => value, :suppressed => 0 ).delete
      }.and_if_constraint_fails {
        raise ConflictException.new("Can't delete a value that's in use: #{value}")
      }
    end


    enum_vals = EnumerationValue.filter( :enumeration_id => obj.id ).order(:position)
    enum_vals.update(:position => Sequel.lit('position + 9999' ))
    enum_vals.each_with_index do |ev, i|
      ev.position = i
      ev.save
    end

    broadcast_changes

    obj.refresh

    existing_default = obj.default_value.nil? ? nil : obj.default_value[:value]

    if opts[:default_value] != existing_default
      if opts[:default_value]
        new_default = EnumerationValue[:value => opts[:default_value]]
        return obj if new_default.nil? #just move along if the default isn't in the values table
        obj.default_value = new_default[:id]
      else
        obj.default_value = nil
      end

      obj.save
    end


    obj
  end


  def self.create_from_json(json, opts = {})
    default_value = json['default_value']
    json['default_value'] = nil

    self.apply_values(super, json, opts.merge({:default_value => default_value}))
  end


  def update_from_json(json, opts = {}, apply_nested_records = true)
    default_value = json['default_value']
    json['default_value'] = nil

    self.class.apply_values(super, json, opts.merge({:default_value => default_value}))
  end


  def self.sequel_to_jsonmodel(objs, opts = {})
    jsons = super

    jsons.zip(objs).each do |json, obj|

      # we're keeping the values as just the not suppressed values.
      # enumeration_values are only needed in situations where we are
      # editing/updating the lists.
      json['values'] = obj.enumeration_value.select {|v| v[:suppressed] != 1 }.map {|v| v[:value] }
      json['readonly_values'] = obj.enumeration_value.map {|v| v[:value] if ( v[:readonly] != 0 && v[:suppressed] != 1 )}.compact
      json['enumeration_values'] = EnumerationValue.sequel_to_jsonmodel(obj.enumeration_value)
      # this tells us where the enum is used.
      json["relationships"] = obj.dependants.collect { |d| d.first[:property] }.uniq

      if obj.default_value
        json['default_value'] = EnumerationValue[:id => obj.default_value][:value]
      end
    end

    jsons
  end


  def self.broadcast_changes
    Notifications.notify("ENUMERATION_CHANGED")
  end


  def self.csv
    out = CSV_HEADERS.to_csv
    Enumeration.sequel_to_jsonmodel(Enumeration.all).sort_by { |e| e.name }.each do |enum|
      enum.enumeration_values.reject { |v| v.suppressed == 1 }.sort_by { |v| v.position }.each do |val|
        out << [
                enum.name,
                I18n.t("enumeration_names.#{enum.name}", :default => enum.name),
                val.value,
                I18n.t("enumerations.#{enum.name}.#{val.value}", :default => val.value),
                val.position,
                val.readonly,
               ].to_csv
      end
    end

    out
  end
end
