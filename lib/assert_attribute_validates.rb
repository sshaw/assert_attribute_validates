#Author: Skye Shaw (sshaw@lucas.cis.temple.edu)
#License: http://www.opensource.org/licenses/mit-license.php
#Description: Test ActiveRecord attribute validations with minimal effort.

module AssertAttributeValidates
  INFERENCE_FAILED_MESSAGE = "No %s argument has been given and I can't infer one from the test %s name".freeze

  def assert_property_validates(*args)    
    options = args.last.is_a?(Hash) ? args.pop.dup : {} 
    instance = create_instance(options[:model])

    possible_properties = instance.class.column_names.join('|')
    property = (args.shift || caller(1).first[/(#{possible_properties}|[a-z0-9]+$)/i, 1]) #Not perfect
    raise INFERENCE_FAILED_MESSAGE % %w|property method's| if property.blank?  #' fix emacs font-lock-mode

    column = instance.column_for_attribute(property)
    if column.nil?
      (column = instance.class.reflections[property.to_sym]) or raise "#{instance.class} has no attribute or association named '#{property}'"
      options[:valid] ||= column.class_name.constantize.new
    else
      #Provide a reasonable default for all types
      options[:valid] ||= column.type_cast('2000-01-01 00:00')
    end

    #If we have no :invalid value or there's a default, the property is probably valid 
    if options.include?(:invalid) || column.respond_to?(:default) && column.default.blank?
      assert !assign_and_validate(instance, property, options[:invalid]), "assigned value '#{instance.send(property)}' should be invalid"      
      if options[:message]
        errors = [ instance.errors[property] ].flatten
        assert errors.include?(options[:message]), "error message(s) should include '#{options[:message]}'; errors are: #{errors.to_sentence}"
      end
    end

    assert assign_and_validate(instance, property, options[:valid]), "#{[ instance.errors[property] ].flatten.to_sentence}"
  end

  private   
  def create_instance(model)
    case model
      when String 
        model.constantize.new
      when Class
        model.new
      when NilClass 
        name = self.class.name[/(\w+)Test$/, 1] or raise INFERENCE_FAILED_MESSAGE % %w|model class'| #' font-lock-mode again
        name.constantize.new 
      else 
        model           
    end
  end

  def assign_and_validate(instance, property, value = nil)
    if !value.nil?
      if value.respond_to?(:call) 
        value.call(instance) 
      else 
        instance.send("#{property}=", value)
      end
    end
    
    instance.valid?
    !instance.errors.invalid?(property)
  end
end

require 'active_support/test_case'
ActiveSupport::TestCase.send(:include, AssertPropertyValidates)
