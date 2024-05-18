using ElasticsearchClient
using ProgressMeter
using Statistics

function score_definitions(os_client, abbreviations_collection)::CollectionDictionary
  result = CollectionDictionary()
  abbr_totals = Dict()

  @showprogress for (abbr, definitions) in collect(abbreviations_collection)
    length(string(abbr)) > 5 && continue
    abbr_totals[abbr] = calc_total(os_client, abbr)

    scores = map(def -> (def, calc_definition_score(os_client, def)), definitions)

    result[abbr] =
      Iterators.take(
        sort(scores, rev=true, by=(def_with_score) -> last(def_with_score)),
        3
      ) |> collect .|> first
  end

  total_mean = mean(last.(collect(abbr_totals)))
  result = filter(collect(result)) do (abbr, defs)
    abbr_totals[abbr] < total_mean / 10
  end |> CollectionDictionary

  result
end

function calc_total(os_client, abbr)
  query = Dict(
    :_source => [],
    :size => 10000,
    :query => Dict(
      :match => Dict(
        :body => abbr
      )
    )
  )

  resp = ElasticsearchClient.search(os_client, index="full_text_search_variant", body=query).body

  resp["hits"]["total"]["value"]
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