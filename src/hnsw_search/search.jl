using ElasticsearchClient
using ElasticsearchClient: client as ElasticClient

using ..TransformerModels

const CHUKS_PER_DOCUMENT = 10
const TOP_K = 5

function search(os_client::ElasticClient, query::AbstractString, size::Integer=25)::Vector{AbstractString}
  transformer = TransformerModels.memoized_transformer()

  query = build_opensearch_query(query, transformer, size)

  results = ElasticsearchClient.search(os_client, index = INDEX_NAME, body=query).body

  map(results["hits"]["hits"]) do hit
    hit["_source"]["metadata"]["document_id"]
  end |>
    unique |>
    doc_ids -> Iterators.take(doc_ids, size) |>
               collect
end

function build_opensearch_query(query, transformer, size)
  Dict(
    :size => max(size * CHUKS_PER_DOCUMENT, 10_000),
    :_source => ["metadata"],
    :query => Dict(
      :knn => Dict(
        :embedding => Dict(
          :vector => vectorize_sentence(transformer, query),
          :k => TOP_K
        )    
      )
    )
  )
end