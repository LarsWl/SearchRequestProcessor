using ..TransformerModels

using ElasticsearchClient
using ElasticsearchClient: Client as ElasticClient
using Graphs, SimpleWeightedGraphs
using JLSO
using Suppressor

function find_similars(query, os_client, walk::ForwardRandomWalk, threshold=0.01)
  transformer = TransformerModels.memoized_transformer()

  os_query = Dict(
    :size => 3,
    :_source => ["query"],
    :query => Dict(
      :knn => Dict(
        :query_embedding => Dict(
          :vector => vectorize_sentence(transformer, query),
          :k => 5
        )
      )
    )
  )

  resp = ElasticsearchClient.search(os_client, index=INDEX_NAME, body=os_query).body

  @debug_output get_debug_id("similar_queries") "ElasticResponse" resp 

  similar_queries = map(hit -> Symbol(hit["_source"]["query"]), resp["hits"]["hits"])

  vertex_id = walk.query_to_vertex_id[Symbol(first(similar_queries))]

  walk_similars = find_similars(walk, vertex_id, threshold)
  # walk_similars = Symbol[]

  unique([similar_queries..., Iterators.take(walk_similars, 2)...])
end

function find_similars(walk::ForwardRandomWalk, vertex_id, threshold)
  distr =
    calc_distribution(walk, vertex_id) |>
    collect |> 
    Vector

  similar =
    findall(>(threshold), distr) |>
    ids -> sort(ids, rev=true, by=(id) -> distr[id])

  vertex_id_to_query = Dict(vertex_id => query for (query, vertex_id) in collect(walk.query_to_vertex_id))

  map(similar) do index
    get(vertex_id_to_query, index, missing)
  end |> skipmissing |> collect
end
