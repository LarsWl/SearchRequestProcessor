using ElasticsearchClient
using ElasticsearchClient: Client as ElasticClient
using WordTokenizers

using ..Abbreviations
using ..SimilarQueries

function baseline_search(os_client::ElasticClient, query::AbstractString, size=25)
  abbreviations = Dict()
  similar_queries = []

  os_query = build_opensearch_query(query, abbreviations, similar_queries, size)

  response = ElasticsearchClient.search(os_client, index=INDEX_NAME, body=os_query).body

  map(hit -> hit["_id"], response["hits"]["hits"])
end

function search(os_client::ElasticClient, query::AbstractString, size=25)
  abbreviations = Abbreviations.extract_abbreviations(query)
  similar_queries = SimilarQueries.extract_similar_queries(query, os_client)

  os_query = build_opensearch_query(query, abbreviations, similar_queries, size)

  response = ElasticsearchClient.search(os_client, index=INDEX_NAME, body=os_query).body

  map(hit -> hit["_id"], response["hits"]["hits"])
end

function build_opensearch_query(query, abbreviations, similar_queries, size)
  Dict(
    :_source => ["title"],
    :size => size,
    :query => Dict(
      :bool => Dict(
        :should => [
          multi_match_query(query, 2),
          collect(
            Iterators.flatten(
              map(collect(abbreviations)) do (abbr, definitions)
                map(definitions) do definition
                  multi_match_query(definition, 0.2)
                end
              end
            )
          )...,
          map(similar_queries) do similar_query
            multi_match_query(similar_query, 1)
          end...
        ]
      )
    )
  )
end

function multi_match_query(query, boost)
  Dict(
    :multi_match => Dict(
      :query => query,
      :type => :best_fields,
      :fields => [
        "title",
        "body",
        "body.shingle"
      ],
      :boost => boost
    )
  )
end