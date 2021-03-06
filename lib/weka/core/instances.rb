require 'weka/core/converters'
require 'weka/core/loader'
require 'weka/core/saver'
require 'weka/core/dense_instance'
require 'weka/concerns/serializable'

module Weka
  module Core
    java_import 'weka.core.Instances'
    java_import 'weka.core.FastVector'

    class Instances
      include Weka::Concerns::Serializable

      DEFAULT_RELATION_NAME = 'Instances'.freeze

      class << self
        def from_arff(file)
          Loader.load_arff(file)
        end

        def from_csv(file)
          Loader.load_csv(file)
        end

        def from_json(file)
          Loader.load_json(file)
        end

        # Loads instances based on a given *.names file (holding the attribute
        # values) or a given *.data file (holding the attribute values).
        # The respective other file is loaded from the same directory.
        #
        # See http://www.cs.washington.edu/dm/vfml/appendixes/c45.htm for more
        # information about the C4.5 file format.
        def from_c45(file)
          Loader.load_c45(file)
        end
      end

      def initialize(relation_name: DEFAULT_RELATION_NAME, attributes: [], &block)
        attribute_list = FastVector.new
        attributes.each { |attribute| attribute_list.add_element(attribute) }

        super(relation_name.to_s, attribute_list, 0)
      end

      def instances
        enumerate_instances.to_a
      end

      def attributes
        enumerate_attributes.to_a
      end

      def attribute_names
        attributes.map(&:name)
      end

      def add_attributes(&block)
        instance_eval(&block) if block
        self
      end

      alias with_attributes  add_attributes
      alias instances_count  num_instances
      alias attributes_count num_attributes

      def each
        if block_given?
          enumerate_instances.each { |instance| yield(instance) }
        else
          enumerate_instances
        end
      end

      def each_with_index
        enumerate_instances.each_with_index do |instance, index|
          yield(instance, index) if block_given?
        end
      end

      def each_attribute
        if block_given?
          enumerate_attributes.each { |attribute| yield(attribute) }
        else
          enumerate_attributes
        end
      end

      def each_attribute_with_index
        enumerate_attributes.each_with_index do |attribute, index|
          yield(attribute, index) if block_given?
        end
      end

      def to_arff(file)
        Saver.save_arff(file: file, instances: self)
      end

      def to_csv(file)
        Saver.save_csv(file: file, instances: self)
      end

      def to_json(file)
        Saver.save_json(file: file, instances: self)
      end

      # Creates a file with the istances's attribute values and a *.data file
      # with the actual data.
      #
      # You should choose another file extension than .data (preferably
      # *.names) for the file, else it will just be overwritten with the
      # automatically created *.data file.
      #
      # See http://www.cs.washington.edu/dm/vfml/appendixes/c45.htm for more
      # information about the C4.5 file format.
      def to_c45(file)
        Saver.save_c45(file: file, instances: self)
      end

      def numeric(name, class_attribute: false)
        attribute = Attribute.new(name.to_s)
        add_attribute(attribute)
        self.class_attribute = name if class_attribute
      end

      def nominal(name, values:, class_attribute: false)
        attribute = Attribute.new(name.to_s, Array(values).map(&:to_s))
        add_attribute(attribute)
        self.class_attribute = name if class_attribute
      end

      def string(name, class_attribute: false)
        attribute = Attribute.new(name.to_s, [])
        add_attribute(attribute)
        self.class_attribute = name if class_attribute
      end

      def date(name, format: 'yyyy-MM-dd HH:mm', class_attribute: false)
        attribute = Attribute.new(name.to_s, format)
        add_attribute(attribute)
        self.class_attribute = name if class_attribute
      end

      def class_attribute=(name)
        if name.nil?
          reset_class_attribute
        else
          ensure_attribute_defined!(name)
          setClass(attribute_with_name(name))
        end
      end

      alias add_numeric_attribute numeric
      alias add_string_attribute  string
      alias add_nominal_attribute nominal
      alias add_date_attribute    date

      def class_attribute
        classAttribute if class_attribute_defined?
      end

      def reset_class_attribute
        set_class_index(-1)
      end

      def class_attribute_defined?
        class_index >= 0
      end

      def add_instance(instance_or_values, weight: 1.0)
        instance = instance_from(instance_or_values, weight: weight)
        add(instance)
      end

      def add_instances(data, weight: 1.0)
        data.each { |values| add_instance(values, weight: weight) }
      end

      def internal_values_of(values)
        values.each_with_index.map do |value, index|
          attribute(index).internal_value_of(value)
        end
      end

      def apply_filter(filter)
        filter.filter(self)
      end

      def apply_filters(*filters)
        filters.inject(self) do |filtered_instances, filter|
          filter.filter(filtered_instances)
        end
      end

      def merge(*instances)
        instances.inject(self) do |merged_instances, dataset|
          self.class.merge_instances(merged_instances, dataset)
        end
      end

      private

      def add_attribute(attribute)
        insert_attribute_at(attribute, attributes.count)
      end

      def ensure_attribute_defined!(name)
        return if attribute_names.include?(name.to_s)

        error   = "\"#{name}\" is not defined."
        hint    = 'Only defined attributes can be used as class attribute!'
        message = "#{error} #{hint}"

        raise ArgumentError, message
      end

      def attribute_with_name(name)
        attributes.select { |attribute| attribute.name == name.to_s }.first
      end

      def instance_from(instance_or_values, weight:)
        if instance_or_values.is_a?(Java::WekaCore::Instance)
          instance_or_values.weight = weight
          instance_or_values
        else
          data = internal_values_of(instance_or_values)
          DenseInstance.new(data, weight: weight)
        end
      end
    end

    Java::WekaCore::Instances.__persistent__ = true
  end
end
