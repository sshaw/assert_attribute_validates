require 'ostruct'
require 'test/unit'
require 'active_record'
require 'assert_attribute_validates'

#This approach is from somehwere...
class NoTable < ActiveRecord::Base
  self.abstract_class = true

  def self.columns
    @columns ||= [];
  end

  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end

  def save(validate = true)
    validate ? valid? : true
  end
end

class Author < NoTable; end
class Article < NoTable
  attr_accessor :author

  column :title, :string
  column :created, :date, Time.now.strftime('%D')
  column :number_of_pages, :int, 1, false

  validates_presence_of :title, :author
  validates_length_of :title, :in => (4..75), :message => 'is too gregarious or terse'
  validates_numericality_of :number_of_pages, :greater_than => 0

  #Mimic AR reflections for test cases
  def self.reflections
    Hash.new { |h, v| h[v] = OpenStruct.new :class_name => 'Author' }
  end
end

class ArticleTest < Test::Unit::TestCase
  include AssertAttributeValidates

  def test_validation
    article = Article.new
    assert_nothing_raised { assert_attribute_validates :title, :model => article }
    assert !article.errors.on(:title)
  end

  def test_model_is_created_from_test_class_name
    assert_nothing_raised { assert_attribute_validates :title }
  end

  def test_attribute_name_is_detected_from_test_name
    article = Article.new
    assert_nothing_raised { some_test_for_number_of_pages_property(article) }
    #Make sure the property was assigned to, number_of_pages defaults to 1
    assert_not_equal 1, article.number_of_pages

    article = Article.new
    assert_nothing_raised { validates_presence_of_title(article) }
    assert article.title?
  end

  def test_error_message_validation
    e = nil
    assert_attribute_validates :title, :message => 'What it izzzz girl!' rescue e = $!.message
    assert_match /^error message/, e
    assert_nothing_raised { assert_attribute_validates :title, :message => 'is too gregarious or terse' }
  end

  def test_validates_asociation
    article = Article.new
    assert_nothing_raised { assert_attribute_validates :author, :model => article }
    assert_not_nil article.author
  end

  def test_error_raised_when_attribute_should_be_invalid
    e = nil
    assert_attribute_validates :title, :invalid => proc { |model| model.title = 'This is valid' } rescue e = $!.message
    assert_match /^assigned value/, e
  end

  def test_error_raised_when_attribute_should_be_valid
    e = nil
    assert_attribute_validates :number_of_pages, :valid => -1 rescue e = $!.message
    assert_match /^must be greater/, e
  end

  private
  def validates_presence_of_title(instance)
    assert_attribute_validates :model => instance
  end

  def some_test_for_number_of_pages_property(instance)
    assert_attribute_validates :model => instance
  end
end

class BadTestCaseName < Test::Unit::TestCase
  include AssertAttributeValidates

  def test_error_raised_when_model_name_cant_be_inferred
    assert_attribute_validates :title rescue e = $!.message
    assert_match /^No model argument/, e
  end
end
