=begin rdoc
--------------------------------------------------------------------------------

Build new Solr index records for a specific set of URIs. If the URI doesn't
represent a Work, Instance, or Agent, it will be noted and ignored.

Specify a directory that holds lists of uris, and a place to put the report.

--------------------------------------------------------------------------------
=end
require "ld4l_browser_data/utilities/uri_processor_helper"

require_relative 'index_specific_uris/bookmark'
require_relative 'index_specific_uris/report'
require_relative 'index_specific_uris/uri_discoverer'

module Ld4lBrowserData
  module Indexing
    class IndexSpecificUris
      include Utilities::MainClassHelper
      include Utilities::TripleStoreUser
      include Utilities::SolrServerUser
      include Utilities::UriProcessorHelper
      def initialize
        @usage_text = [
          'Usage is ld4l_index_specific_uris \\',
          'source=<source_file_or_directory> \\',
          'report=<report_file>[~REPLACE] \\',
          '[capture_state=<state_file>[~REPLACE]] \\',
          '[IGNORE_BOOKMARK] \\',
          '[CLEAR_INDEX] \\',
          '[IGNORE_SITE_SURPRISES] \\',
        ]
      end

      def process_arguments()
        parse_arguments(:source, :report, :capture_state, :IGNORE_BOOKMARK, :CLEAR_INDEX, :IGNORE_SITE_SURPRISES)
        @source_files = SourceFiles.new(validate_input_source(:source, "source_file_or_directory"))
        @report = Report.new(validate_output_file(:report, "report file"))
        @state_file = validate_output_file(:capture_state, "state file") if @args[:capture_state]
        @ignore_bookmark = @args[:IGNORE_BOOKMARK]
        @ignore_surprises = @args[:IGNORE_SITE_SURPRISES]
        @clear_index = @args[:CLEAR_INDEX]
        @report.log_header
      end

      def check_for_surprises
        check_site_consistency(@ignore_surprises, {
          'Triple store' => @ts,
          'Report path' => @report,
          'Source file or directory' => @source_files,
        })
      end

      def prepare_document_factory
        @doc_factory = IndexDocuments::DocumentFactory.new(@ts)
      end

      def do_it
        uris = UriDiscoverer.new(@bookmark, @ts, @report, @source_files)
        uris.each do |type, uri|
          if @interrupted
            process_interruption
            raise UserInputError.new("INTERRUPTED")
          else
            begin
              doc = @doc_factory.document(type, uri)
              @ss.add_document(doc.document) if doc
              error_monitor.good
            rescue DocumentError
              @report.log_document_error(type, uri, $!.doc, $!.cause)
              error_monitor.failed
            rescue
              @report.log_document_error(type, uri, doc, $!)
              error_monitor.failed
            end
          end
        end
      end

      def capture_state
        state = {
          agents: @doc_factory.agent_stats,
          instances: @doc_factory.instance_stats,
          works: @doc_factory.work_stats,
        }
        File.open(@state_file, 'w') do |f|
          f.puts JSON.pretty_generate(state)
        end
      end

      def initialize_bookmark
        @bookmark = Bookmark.new(@source_files.basename, @ss, @ignore_bookmark)
      end

      def trap_control_c
        @interrupted = false
        trap("SIGINT") do
          @interrupted = true
        end
      end

      def process_interruption
        @ss.commit
        @bookmark.persist
        @report.summarize(@doc_factory, @bookmark, :interrupted)
        capture_state if @state_file
      end

      def run()
        begin
          process_arguments
          connect_solr_server(@clear_index)
          connect_triple_store
          prepare_document_factory
          initialize_bookmark
          trap_control_c

          do_it

          @ss.commit
          @report.summarize(@doc_factory, @bookmark)
          capture_state if @state_file
          @bookmark.complete
        rescue UserInputError
          puts
          puts "ERROR: #{$!}"
          puts
          exit 1
        ensure
          @report.close if @report
        end
      end
    end
  end
end