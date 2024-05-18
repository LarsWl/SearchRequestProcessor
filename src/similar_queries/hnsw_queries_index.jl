using ..TransformerModels

using ElasticsearchClient
using JSON
using ProgressMeter
using CSV
using Statistics

const INDEX_NAME = "queries_hnsw"
const MSMARCO_INDEX_NAME = "msmarco_queries_hnsw"

function create_queries_index(os_client::ElasticsearchClient.Client, estimated_queries::Vector{Tuple{String,AbstractFloat}}, index_name::String)
  if !ElasticsearchClient.Indices.exists(os_client, index=index_name)
    mapping = JSON.parsefile("var/configs/queries_hnsw.json")
  
    ElasticsearchClient.Indices.create(os_client, index=index_name, body=mapping)
  end

  batch = AbstractDict[]
  mutex = ReentrantLock()

  transformer = TransformerModels.get_transformer()

  @showprogress Threads.@threads for (query, score) in estimated_queries
    doc = Dict(
      :index => Dict(
        :_index => index_name,
        :data => Dict(
          :query => query,
          :query_score => score,
          :query_embedding => vectorize_sentence(transformer, string(query))
        )
      )
    )
  
    lock(mutex) do 
      push!(batch, doc)
  
      if length(batch) == 250
        ElasticsearchClient.bulk(os_client, body=batch)
    
        empty!(batch)
      end 
    end
  end

  ElasticsearchClient.Indices.refresh(os_client, index=index_name)
end

function estimate_queries(os_client::ElasticsearchClient.Client, queries::Vector{String})::Vector{Tuple{String, AbstractFloat}}
  estimated_queries = Tuple{String, AbstractFloat}[]
  mutex = ReentrantLock()

  @showprogress Threads.@threads for query in queries
    elastic_query = Dict(
      :_source => String[],
      :size => 20,
      :query => Dict(
        :match => Dict(:body => query)
      )
    )

    response = ElasticsearchClient.search(os_client, body=elastic_query).body
    hits = response["hits"]["hits"]
    
    length(hits) < 10 && continue

    score = map(h -> h["_score"], hits) |> mean

    lock(mutex) do
      push!(estimated_queries, (query, score))
    end
  end

  estimated_queries = sort(estimated_queries, by=last, rev=true)

  estimated_queries
end

function create_msmarco_queries_index(os_client::ElasticsearchClient.Client)
  
end
