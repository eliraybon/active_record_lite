require_relative 'db_connection'
require 'active_support/inflector'

class SQLObject
  def self.columns
    return @columns if @columns
    columns = DBConnection.execute2(<<-SQL).first
      SELECT
        *
      FROM
        #{self.table_name}
      LIMIT
        0
    SQL
    @columns = columns.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |name|
      define_method(name) do 
        self.attributes[name]
      end

      define_method("#{name}=") do |value|
        self.attributes[name] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL

    parse_all(results)
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        id = ?
    SQL

    parse_all(results).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      if self.class.columns.include?(attr_name)
        self.send("#{attr_name}=", value)
      else 
        raise "unknown attribute '#{attr_name}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |attr| self.send(attr) }
  end

  def insert
    columns = self.class.columns.drop(1) #drop(1) gets rid of the id
    column_names = columns.map(&:to_s).join(', ') #formats for SQL query
    question_marks = (['?'] * columns.count).join(', ') #for SQL query

    DBConnection.execute(<<-SQL, *self.attribute_values.drop(1))
      INSERT INTO
        #{self.class.table_name} (#{column_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set = self.class.columns.map { |attr| "#{attr} = ?" }.join(', ')

    DBConnection.execute(<<-SQL, *self.attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set}
      WHERE
        id = ? 
    SQL
  end

  def save
    self.id ? self.update : self.insert
  end
end
