module SimilarQueries

include("bipartite_graph.jl")
include("hnsw_queries_index.jl")
include("similar_search.jl")

function extract_similar_queries(query::AbstractString, os_client)::Vector{String}
  walk = memozied_forward_walk()

  find_similars(query, os_client, walk) .|> string
end

end
