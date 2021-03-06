require 'builder'
require 'intacct_ruby/exceptions/unknown_function_type'

module IntacctRuby
  # a function to be sent to Intacct. Defined by a function type (e.g. :create),
  # an object type, (e.g. :customer), and parameters.
  class Function
    ALLOWED_TYPES = %w(
      readByQuery
      read
      readByName
      readMore
      create
      update
      delete
      create_sotransaction
      update_sotransaction
    ).freeze

    CU_TYPES = %w(create update).freeze

    CAMEL_CASE_TYPES = %w(
      readMore
    ).freeze

    LCASE_TYPES = %w(
      delete
      readByQuery
      read
      readByName
      create_sotransaction
      update_sotransaction
    ).freeze

    OPS_REQUIRING_OBJ_KEY = %w(
      'update_sotransaction'
    ).freeze

    def initialize(function_type, object_type: nil, object_key: nil, parameters:)
      @function_type = function_type.to_s
      @object_type = object_type.to_s
      @object_key = object_key.to_s
      @parameters = parameters

      validate_type!
      validate_args!
    end

    def to_xml
      xml = Builder::XmlMarkup.new

      xml.function controlid: controlid do
        element_attrs = {}
        element_attrs[:key] = @object_key if @object_key.present?
        xml.tag!(@function_type, element_attrs) do
          if CU_TYPES.include?(@function_type)
            xml.tag!(@object_type) do
              xml << parameter_xml(@parameters)
            end
          elsif LCASE_TYPES.include?(@function_type)
            xml << parameter_xml(@parameters, to_case: :downcase)
          elsif CAMEL_CASE_TYPES.include?(@function_type)
            xml << parameter_xml(@parameters, to_case: nil)
          else
            xml << parameter_xml(@parameters)
          end
        end
      end
      xml.target!
    end

    private

    def timestamp
      @timestamp ||= Time.now.utc.to_s
    end

    def controlid
      "#{@function_type}-#{@object_type}-#{timestamp}"
    end

    def parameter_xml(parameters_to_convert, options = {})
      default_options = { to_case: :upcase }
      options = options.reverse_merge!(default_options)

      xml = Builder::XmlMarkup.new

      parameters_to_convert.each do |key, value|
        parameter_key = case options[:to_case]
                        when :upcase
                          key.to_s.upcase
                        when :downcase
                          key.to_s.downcase
                        else
                          key.to_s
                        end

        xml.tag!(parameter_key) do
          xml << parameter_value_as_xml(value, options)
        end
      end

      xml.target!
    end

    def parameter_value_as_xml(value, options = {})
      case value
      when Hash
        parameter_xml(value, options) # recursive case
      when Array
        parameter_value_list_xml(value, options) # recursive case
      else
        value.to_s.encode(xml: :text) # end case
      end
    end

    def parameter_value_list_xml(array_of_hashes, options = {})
      xml = Builder::XmlMarkup.new

      array_of_hashes.each do |parameter_hash|
        xml << parameter_xml(parameter_hash, options)
      end

      xml.target!
    end

    def validate_type!
      unless ALLOWED_TYPES.include?(@function_type)
        raise Exceptions::UnknownFunctionType,
              "Type #{@object_type} not recognized. Function Type must be " \
              "one of #{ALLOWED_TYPES}."
      end
    end

    def validate_args!
      if OPS_REQUIRING_OBJ_KEY.include?(@function_type) && @object_key.blank?
        raise Exceptions::InvalidArgumentsException,
          "#{@function_type} cannot be executed without an object key."
      end
    end
  end
end
