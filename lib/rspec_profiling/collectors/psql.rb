require "pg"
require "active_record"

module RspecProfiling
  module Collectors
    class PSQL
      def self.install
        new.install
      end

      def self.uninstall
        new.uninstall
      end

      def self.reset
        new.results.destroy_all
      end

      def initialize
        RspecProfiling.config.db_path ||= 'rspec_profiling'
        establish_connection
      end

      def install
        return if prepared?

        connection.create_table(table) do |t|
          t.string    :commit
          t.datetime  :date
          t.text      :file
          t.integer   :line_number
          t.text      :description
          t.decimal   :time
          t.string    :status
          t.text      :exception
          t.integer   :query_count
          t.decimal   :query_time
          t.integer   :request_count
          t.decimal   :request_time
          t.timestamps null: true
        end
      end

      def uninstall
        connection.drop_table(table)
      end

      def insert(attributes)
        results.create!(attributes.except(:created_at))
      end

      def results
        @results ||= begin
          establish_connection

          Result.table_name = table
          Result.attr_protected if Result.respond_to?(:attr_protected)
          Result
        end
      end

      private

      def prepared?
        connection.table_exists?(table)
      end

      def connection
        @connection ||= results.connection
      end

      def establish_connection
        begin
          PG.connect(dbname: 'postgres').exec("CREATE DATABASE #{database}")
        rescue PG::DuplicateDatabase
          # no op
        end

        Result.establish_connection(
          :adapter  => 'postgresql',
          :database => database
        )
      end

      def table
        RspecProfiling.config.table_name
      end

      def database
        RspecProfiling.config.db_path
      end

      class Result < ActiveRecord::Base
        def to_s
          [description, location].join(" - ")
        end

        private

        def location
          [file, line_number].join(":")
        end
      end
    end
  end
end
