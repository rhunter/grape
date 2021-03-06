require 'spec_helper'
require 'grape_entity'

describe Grape::Entity do
  subject { Class.new(Grape::API) }
  def app; subject end

  describe '#present' do
    it 'sets the object as the body if no options are provided' do
      subject.get '/example' do
        present({:abc => 'def'})
        body.should == {:abc => 'def'}
      end
      get '/example'
    end

    it 'calls through to the provided entity class if one is given' do
      subject.get '/example' do
        entity_mock = Object.new
        entity_mock.should_receive(:represent)
        present Object.new, :with => entity_mock
      end
      get '/example'
    end

    it 'pulls a representation from the class options if it exists' do
      entity = Class.new(Grape::Entity)
      entity.stub!(:represent).and_return("Hiya")

      subject.represent Object, :with => entity
      subject.get '/example' do
        present Object.new
      end
      get '/example'
      last_response.body.should == 'Hiya'
    end

    it 'pulls a representation from the class options if the presented object is a collection of objects' do
      entity = Class.new(Grape::Entity)
      entity.stub!(:represent).and_return("Hiya")

      class TestObject; end

      subject.represent TestObject, :with => entity
      subject.get '/example' do
        present [TestObject.new]
      end
      get '/example'
      last_response.body.should == "Hiya"
    end

    it 'pulls a representation from the class ancestor if it exists' do
      entity = Class.new(Grape::Entity)
      entity.stub!(:represent).and_return("Hiya")

      subclass = Class.new(Object)

      subject.represent Object, :with => entity
      subject.get '/example' do
        present subclass.new
      end
      get '/example'
      last_response.body.should == 'Hiya'
    end

    it 'automatically uses Klass::Entity if that exists' do
      some_model = Class.new
      entity = Class.new(Grape::Entity)
      entity.stub!(:represent).and_return("Auto-detect!")

      some_model.const_set :Entity, entity

      subject.get '/example' do
        present some_model.new
      end
      get '/example'
      last_response.body.should == 'Auto-detect!'
    end

    it 'automatically uses Klass::Entity based on the first object in the collection being presented' do
      some_model = Class.new
      entity = Class.new(Grape::Entity)
      entity.stub!(:represent).and_return("Auto-detect!")

      some_model.const_set :Entity, entity

      subject.get '/example' do
        present [some_model.new]
      end
      get '/example'
      last_response.body.should == 'Auto-detect!'
    end

    it 'adds a root key to the output if one is given' do
      subject.get '/example' do
        present({:abc => 'def'}, :root => :root)
        body.should == {:root => {:abc => 'def'}}
      end
      get '/example'
    end

    [ :json, :serializable_hash ].each do |format|

      it 'presents with #{format}' do
        entity = Class.new(Grape::Entity)
        entity.root "examples", "example"
        entity.expose :id

        subject.format format
        subject.get '/example' do
          c = Class.new do
            attr_reader :id
            def initialize(id)
              @id = id
            end
          end
          present c.new(1), :with => entity
        end

        get '/example'
        last_response.status.should == 200
        last_response.body.should == '{"example":{"id":1}}'
      end

      it 'presents with #{format} collection' do
        entity = Class.new(Grape::Entity)
        entity.root "examples", "example"
        entity.expose :id

        subject.format format
        subject.get '/examples' do
          c = Class.new do
            attr_reader :id
            def initialize(id)
              @id = id
            end
          end
          examples = [ c.new(1), c.new(2) ]
          present examples, :with => entity
        end

        get '/examples'
        last_response.status.should == 200
        last_response.body.should == '{"examples":[{"id":1},{"id":2}]}'
      end

    end

    it 'presents with xml' do
      entity = Class.new(Grape::Entity)
      entity.root "examples", "example"
      entity.expose :name

      subject.format :xml

      subject.get '/example' do
        c = Class.new do
          attr_reader :name
          def initialize(args)
            @name = args[:name] || "no name set"
          end
        end
        present c.new({:name => "johnnyiller"}), :with => entity
      end
      get '/example'
      last_response.status.should == 200
      last_response.headers['Content-type'].should == "application/xml"
      last_response.body.should == <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<hash>
  <example>
    <name>johnnyiller</name>
  </example>
</hash>
XML
    end

    it 'presents with json' do
      entity = Class.new(Grape::Entity)
      entity.root "examples", "example"
      entity.expose :name

      subject.format :json

      subject.get '/example' do
        c = Class.new do
          attr_reader :name
          def initialize(args)
            @name = args[:name] || "no name set"
          end
        end
        present c.new({:name => "johnnyiller"}), :with => entity
      end
      get '/example'
      last_response.status.should == 200
      last_response.headers['Content-type'].should == "application/json"
      last_response.body.should == '{"example":{"name":"johnnyiller"}}'
    end

    it 'presents with jsonp and a custom formatter' do
      entity = Class.new(Grape::Entity)
      entity.root "examples", "example"
      entity.expose :name

      subject.content_type :jsonp, 'application/javascript'
      subject.formatter :jsonp, lambda { |object, env| object.to_json }
      subject.format :jsonp

      subject.get '/example' do
        c = Class.new do
          attr_reader :name
          def initialize(args)
            @name = args[:name] || "no name set"
          end
        end

        present c.new({:name => "johnnyiller"}), :with => entity
      end
      get '/example'
      last_response.status.should == 200
      last_response.headers['Content-type'].should == "application/javascript"
      last_response.body.should == '{"example":{"name":"johnnyiller"}}'
    end

  end

end
