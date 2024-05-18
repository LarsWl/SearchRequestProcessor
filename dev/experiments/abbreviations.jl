using SearchRequestProcessor
using DebugDataWriter
using JLSO
using ElasticsearchClient
using Statistics

DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = true

r = SearchRequestProcessor.Abbreviations.parse_wikidata_abbreviations()

existing_abbrs = SearchRequestProcessor.Abbreviations.parse_new_abbreviations()

os_client = ElasticsearchClient.Client(verbose=0)
abbreviations_collection = SearchRequestProcessor.Abbreviations.score_definitions(os_client, existing_abbrs)

JLSO.save(SearchRequestProcessor.Abbreviations.COLLECTION_DICTIONARY_PATH, :abbreviations_collection => abbreviations_collection)

tokens = @show existing_abbrs |> keys

buildquery(q) = Dict(
    :_source => [],
    :query => Dict(
        :match => Dict(
            :body => q
        )
    ),
    size=>10_000
)

query = buildquery(:VBA)
resp = ElasticsearchClient.search(os_client, body=query).body

resp["hits"]

totalfunc(q) = begin
    query = buildquery(q)
    ElasticsearchClient.search(os_client, body=query).body["hits"]["total"]["value"]
end

tokens_total = Dict(
    token => totalfunc(token) for token in tokens
)
tokens_total = tokens_total |> collect
mean_total = mean(last.(tokens_total))
filtered_tokens = filter(t -> (last(t) < (mean_total / 10)) && length(string(first(t))) <= 5, tokens_total)

first(filtered_tokens) |> first |> string |> length

query = "swan fin"

SearchRequestProcessor.Abbreviations.extract_abbreviations(query)