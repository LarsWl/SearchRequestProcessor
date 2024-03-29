using ElasticsearchClient
using ProgressMeter
using Statistics

function score_definitions(os_client, abbreviations_collection)::CollectionDictionary
  result = CollectionDictionary()

  @showprogress for (abbr, definitions) in collect(abbreviations_collection)
    scores = map(def -> (def, calc_definition_score(os_client, def)), definitions)

    result[abbr] =
      Iterators.take(
        sort(scores, rev=true, by=(def_with_score) -> last(def_with_score)),
        3
      ) |> collect .|> first
  end

  result
end

function calc_definition_score(os_client, definition)
  query = Dict(
    :_source => [],
    :size => 10,
    :query => Dict(
      :multi_match => Dict(
        :query => definition,
        :type => :cross_fields,
        :fields => [
          "title",
          "body",
          "body.shingle"
        ]
      )
    )
  )

  response = ElasticsearchClient.search(os_client, index="full_text_search_variant", body=query).body

  isempty(response["hits"]["hits"]) && return 0

  mean(map(h -> h["_score"], response["hits"]["hits"]))
end