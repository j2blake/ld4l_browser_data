=begin

At startup, load the languages file.

When requested, find the English-language label of a language instance.
If not found, return nil.

We're looking for a statement like this:
<http://id.loc.gov/vocabulary/languages/eng> <http://www.w3.org/2004/02/skos/core#prefLabel> "English"@en .

[Shares a lot of code with Ld4lIndexing::TopicReference]

=end

module Ld4lBrowserData
  module Indexing
    class LanguageReference
      class << self
        begin
          @@graph = RDF::Graph.load(File.join(File.dirname(__FILE__), 'data', 'loc_lang.rdf'))
          @@pref_label = RDF::URI.new('http://www.w3.org/2004/02/skos/core#prefLabel')
        end

        def lookup(language_uri)
          query = RDF::Query.new do
            pattern [RDF::URI.new(language_uri), @@pref_label, :label]
          end

          query.execute(@@graph).each do |solution|
            label = solution[:label]
            return label.value if label.language.to_s == 'en'
          end

          nil
        end
      end
    end
  end
end
