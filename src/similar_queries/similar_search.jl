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
    :_source => ["query", "query_score"],
    :query => Dict(
      :knn => Dict(
        :query_embedding => Dict(
          :vector => vectorize_sentence(transformer, query),
          :k => 5
        )
      )
    )
  )

  graph_req_t = @async ElasticsearchClient.search(os_client, index=INDEX_NAME, body=os_query)
  corpus_req_t = @async ElasticsearchClient.search(os_client, index=MSMARCO_INDEX_NAME, body=os_query)

  wait(graph_req_t)

  graph_resp = graph_req_t.result.body
  graph_similar_hits = graph_resp["hits"]["hits"]
  @debug_output get_debug_id("graph_similar_hits") "Graph Similars" graph_similar_hits

  # vertex_id = walk.query_to_vertex_id[Symbol(first(graph_similar_hits)["_source"]["query"])]
  # walk_similars_task = @async find_similars(walk, vertex_id, threshold)

  wait(corpus_req_t)

  corpus_resp = corpus_req_t.result.body
  corpus_similar_hits = corpus_resp["hits"]["hits"]
  @debug_output get_debug_id("corpus_similar_hits") "Corpus Similars" corpus_similar_hits

  similar_queries =
    [graph_similar_hits..., corpus_similar_hits...] |>
    queries -> filter(q -> q["_score"] > 0.75, queries) |>
               queries -> sort(queries, by=q -> q["_source"]["query_score"] * q["_score"]^2, rev=true) |>
                          queries -> map(q -> q["_source"]["query"], queries) |>
                                     unique |>
                                     queries -> Iterators.take(queries, 3) |>
                                                collect

  # wait(walk_similars_task)

  # walk_similars = walk_similars_task.result
  # @debug_output get_debug_id("walk_similar_queries") "Walk Similars" walk_similars

  # if length(walk_similars) > 0
  #   push!(similar_queries, string(first(walk_similars)))
  # end

  unique(similar_queries)
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
