require 'benchmark'
require 'erb'
require 'fileutils'
require 'json'
require 'net/http'
require 'net/telnet'
require 'ostruct'
require "uri"

require_relative "triple_store_drivers/http_handler"

require_relative "triple_store_drivers/base_driver"
require_relative "triple_store_drivers/blaze_graph"
require_relative "triple_store_drivers/four_store"
require_relative "triple_store_drivers/fuseki2"
require_relative "triple_store_drivers/instrumented_wrapper"
require_relative "triple_store_drivers/sesame"
require_relative "triple_store_drivers/virtuoso"
require_relative "triple_store_drivers/virtuoso_pro"

module Ld4lBrowserData
  module TripleStoreDrivers
    # The triple store didn't do what we wanted or expected.
    class DriverError < StandardError
    end

    # No current settings
    NO_CURRENT_SETTINGS = :no_settings

    # A triple-store with the current settings is running.
    SELECTED_TRIPLE_STORE_RUNNING = :running

    # No triple-store is running.
    NO_TRIPLE_STORE_RUNNING = :not_running

    class Status
      attr_reader :value
      attr_reader :description
      def initialize(value, description)
        @value = value
        @description = description
      end

      def running?
        SELECTED_TRIPLE_STORE_RUNNING == value
      end

      def to_s
        "#{value} -- #{description}"
      end
    end

    class << self
      #
      # Store these settings for the current triple-store operations.
      #
      # Raises Ld4lBrowserData::SettingsError if the settings are incomplete
      # or inconsistent.
      #
      def select(settings)
        @settings = Hash[settings]
        class_name = @settings[:class_name]
        raise SettingsError.new("Settings must contain a value for :class_name") unless class_name
        begin
          clazz = class_name.split('::').inject(Object) {|o,c| o.const_get c}
          @instance = clazz.new(@settings)
        rescue Exception => e
          @instance = nil
          raise SettingsError.new("Can't create an instance of #{class_name}: #{e.message}")
        end
      end

      #
      # Get a reference to the current triple-store instance.
      #
      # Returns nil if TripleStoreDrivers::select has not been called.
      #
      def selected()
        @instance
      end

      #
      # Find the current status of the triple-store. 'value' will be one of the
      # status constants, 'description' will be text that can be displayed.
      #
      # Are there settings? Is the current instance running? Is another instance running?
      #
      def status()
        return Status.new(NO_CURRENT_SETTINGS, "No settings.") unless @instance
        return Status.new(SELECTED_TRIPLE_STORE_RUNNING, "Running: #{@instance}") if @instance.running?
        return Status.new(NO_TRIPLE_STORE_RUNNING, "Not running: #{@instance}")
      end

      #
      # Start a triple-store instance using the current settings.
      #
      # If a block is provided, yield the instance of the triple-store, and
      # insure that shutdown will be called. Otherwise, return the instance.
      #
      # Raises Ld4lBrowserData::IllegalStateError if a triple-store is
      # already running. Raises Ld4lBrowserData::TripleStoreDrivers::DriverError
      # if the triple-store fails to start.
      #
      def startup()
        raise IllegalStateError.new("No triple-store settings.") unless @instance
        s = status
        raise IllegalStateError.new("Stop the triple-store first: #{s.description}") unless s.value == NO_TRIPLE_STORE_RUNNING

        begin
          @instance.open
          if block_given?
            begin
              yield @instance
            ensure
              shutdown
            end
          else
            return @instance
          end
        rescue Exception => e
          raise DriverError.new("Failed to open the triple-store <#{@instance}>: #{e.message}")
        end
      end

      #
      # Stop any running triple-store, regardless of whether it matches the
      # current settings.
      #
      # Raises Ld4lBrowserData::TripleStoreDrivers::DriverError if the 
      # triple-store fails to stop.
      #
      # Will not raise Ld4lBrowserData::IllegalStateError. Call it any time to
      # be sure that no triple-store is running.
      #
      def shutdown()
        begin
          @instance.close if @instance && @instance.running?
        rescue Exception => e
          warning("Failed to stop the triple-store: #{e.message}")
          puts e.backtrace.join("\n")
        end

        raise DriverError.new("Failed to stop the triple-store: status is #{status}") if status.running?()
      end

      def warning(message)
        puts "WARNING: #{message}"
      end

      # --------------------------------------------------------------------------
      private
      # --------------------------------------------------------------------------

      #
      # Forget that we have settings or an instance. Use in unit tests.
      #
      def reset()
        @settings = nil
        @instance = nil
        @mode = nil
        BaseDriver.send(:reset)
      end
    end
  end
end
