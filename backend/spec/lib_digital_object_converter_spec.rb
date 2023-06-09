# encoding: utf-8
require 'spec_helper'
require 'converter_spec_helper'

require_relative '../app/converters/digital_object_converter'

describe 'Digital Object converter' do

  def my_converter
    DigitalObjectConverter
  end


  before(:all) do
    test_file = File.expand_path("../../templates/aspace_digital_object_import_template.csv",
                                 File.dirname(__FILE__))
    @records = convert(test_file)
    @digital_objects = @records.select {|r| r['jsonmodel_type'] == 'digital_object' }
  end


  it "did something" do
    expect(@digital_objects[0]).not_to be_nil

    expect(@digital_objects[0]['jsonmodel_type']).to eq('digital_object')
    expect(@digital_objects[0]['level']).to eq('image')
    expect(@digital_objects[0]['title']).to eq('a new digital object')
    expect(@digital_objects[0]['publish']).to be_truthy
  end



  it "maps digital_object_file version information to the object" do
    expect(@digital_objects[0]['file_versions'].length).to eq(1)
    {"jsonmodel_type"=>"file_version", "uri"=>nil, "file_uri"=>"http://aspace.me", "publish"=>true, "use_statement"=>"It's all good", "xlink_actuate_attribute"=>"onRequest", "xlink_show_attribute"=>"embed", "file_format_name"=>"jpeg", "file_format_version"=>"1", "file_size_bytes"=>100, "checksum"=>"xxxxxxx", "checksum_method"=>"md5"}.each do |k, v|
      expect(@digital_objects[0]["file_versions"][0][k]).to eq(v)
    end
  end


  describe "utf-8 encoding" do
    let(:test_file_bom) {
      File.expand_path('./examples/digital_object/test_digital_object_utf8_bom.csv',
                       File.dirname(__FILE__))
    }

    it "does something even if its a kooky utf-8 file with a BOM" do
      @records = convert(test_file_bom)
      @digital_objects = @records.select {|r| r['jsonmodel_type'] == 'digital_object' }

      expect(@digital_objects[0]).not_to be_nil

      expect(@digital_objects[0]['jsonmodel_type']).to eq('digital_object')
      expect(@digital_objects[0]['title']).to eq('DO test ¥j¥ü¥Ó/anne')
    end
  end
end
