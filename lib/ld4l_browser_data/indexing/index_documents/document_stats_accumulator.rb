require 'ld4l_browser_data/utilities/warnings_counter'

module Ld4lBrowserData
  module Indexing
    module IndexDocuments
      class DocumentStatsAccumulator
        attr_reader :docs_count
        def initialize(label)
          @label = label
          @docs_count = 0
          @predicate_counts = CountsMap.new
          @value_counts = CountsMap.new
          @warning_counts = Utilities::WarningsCounter.new
        end

        def record(doc)
          record_document(doc)
          record_predicates(doc)
          record_values(doc)
        end

        def record_document(doc)
          @docs_count += 1
        end

        # properties is an array of maps
        def record_predicates(doc)
          counts_map = Hash.new {0}
          doc.properties.each do |prop|
            counts_map[prop['p']] += 1
          end
          counts_map.each do |k, v|
            @predicate_counts.add_occurences(k, v)
          end
        end

        # values is a map of arrays
        def record_values(doc)
          doc.values.each do |k, v|
            @value_counts.add_occurences(k, v.size) unless v.empty?
          end
        end

        def warning(message, uri='NO URI')
          @warning_counts.record_warning(message, uri)
        end

        def to_s()
          "\n%s: %s\nPREDICATES:\n%s\nVALUES:\n%s\nWARNINGS:\n%s" % [@label, @docs_count, format_predicate_counts, format_value_counts, format_warnings]
        end

        def format_predicate_counts
          header = "   count    #docs   property"
          @predicate_counts.to_a.sort {|a, b| a[0] <=> b[0]}.inject([header]) do |lines, item|
            lines << "%8d  %8d   %s" % [item[1].occurences, item[1].docs_count, item[0]]
          end.join("\n")
        end

        def format_value_counts
          header = "   count    #docs   value"
          @value_counts.to_a.sort {|a, b| a[0] <=> b[0]}.inject([header]) do |lines, item|
            lines << "%8d  %8d   %s" % [item[1].occurences, item[1].docs_count, item[0]]
          end.join("\n")
        end

        def format_warnings
          if @warning_counts.empty?
            "   No warnings"
          else
            header = "   count   message"
            @warning_counts.items.inject([header]) do |lines, item|
              lines << "%8d   %s" % [item.count, item.message]
              item.examples.each do |example|
                lines << "              #{example}"
              end
              lines << "              ..." if item.count > item.examples.size
              lines
            end.join("\n")
          end
        end

        def to_json(*a)
          {
            count: @docs_count,
            predicates: @predicate_counts,
            values: @value_counts,
            warnings: @warning_counts,
          }.to_json(*a)
        end

        class Counter
          attr_reader :docs_count
          attr_reader :occurences
          def initialize()
            @docs_count = 0
            @occurences = 0
          end

          def add_occurences(count)
            @docs_count += 1
            @occurences += count
          end

          def to_json(*a)
            {
              docs_count: @docs_count,
              occurences: @occurences,
            }.to_json(*a)
          end
        end

        class CountsMap < Hash
          def add_occurences(key, count)
            counter = fetch(key, Counter.new)
            counter.add_occurences(count)
            store(key, counter)
          end
        end
      end
    end
  end
end
