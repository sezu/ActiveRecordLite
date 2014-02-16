require_relative 'db_connection'
require_relative '01_mass_object'
require 'active_support/inflector'
#String#underscore
#String#pluralize

class MassObject
  def self.parse_all(results)
    results.map{ |result| self.new(result) }
  end
end

class SQLObject < MassObject
  def self.columns
    #return an array of the names of the columns that this model contains
    columns = DBConnection.execute2("SELECT * FROM #{self.table_name}").first

    columns.each do |column|
      define_method("#{column}"){ self.attributes[column] }
      define_method("#{column}="){ |val| self.attributes[column] = val }
    end

    columns.map(&:to_sym)
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.to_s.downcase.pluralize.underscore
  end

  def self.all
    #return an array of all the records in the DB
    results = DBConnection.execute("SELECT * FROM #{self.table_name}")
    parse_all(results)
  end

  def self.find(id)
    #look up a single record by primary key
    result = DBConnection.execute(<<-SQL, id)
    SELECT
      *
    FROM
      #{self.table_name}
    WHERE
      id = ?
    SQL
    result.map{ |result| self.new(result) }.first
  end

  def attributes
    @attributes ||= Hash.new
  end

  def insert
    # insert a new row into the table to represent the SQLObject
    col_names = @attributes.keys.join(", ")
    question_marks = (["?"] * @attributes.count).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values)
    INSERT INTO
      #{self.class.table_name} (#{col_names})
    VALUES
      (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      name = attr_name.to_sym
      raise "unknown attribute #{name}" unless self.class.columns.include?(name)
      self.send("#{name}=", value)
    end
  end

  def save
    #convenience method that either calls insert/update
    #depending on whether the SQLObject already exists in the table.
    if self.id
      update
    else
      insert
    end
  end

  def update
    #update the row with the id of this SQLObject
    set_line = attributes.map{|attr_name, val| "#{attr_name} = ?" }.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values, self.id)
    UPDATE
      #{self.class.table_name}
    SET
      #{set_line}
    WHERE
      id = ?
    SQL
  end

  def attribute_values
    @attributes.values
  end
end
