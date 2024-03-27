module HybridSearch

using OpenAI

include("indexation.jl")
include("openai.jl")
include("search.jl")

const INDEX_NAME = "hybrid_search_variant"

end
