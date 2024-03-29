using ..TransformerModels

using ElasticsearchClient
using JSON
using ProgressMeter

const INDEX_NAME = "queries_hnsw"

function create_queries_index(os_client::ElasticsearchClient.Client, walk::ForwardRandomWalk)
  if !ElasticsearchClient.Indices.exists(os_client, index=INDEX_NAME)
    mapping = JSON.parsefile("var/configs/queries_hnsw.json")
  
    ElasticsearchClient.Indices.create(os_client, index=INDEX_NAME, body=mapping)
  end

  queries = collect(keys(walk.query_to_vertex_id))
  queries = queries[range(1, length(queries), step=5)]

  batch = AbstractDict[]

  transformer = TransformerModels.get_transformer()

  @showprogress for query in queries
    doc = Dict(
      :index => Dict(
        :_index => INDEX_NAME,
        :data => Dict(
          :query => query,
          :query_embedding => vectorize_sentence(transformer, string(query))
        )
      )
    )
  
    push!(batch, doc)
  
    if length(batch) == 250
      ElasticsearchClient.bulk(os_client, body=batch)
  
      empty!(batch)
    end
  end

  ElasticsearchClient.Indices.refresh(os_client, index=INDEX_NAME)
end
