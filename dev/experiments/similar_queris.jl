using SearchRequestProcessor
using DebugDataWriter
using Graphs
using JLSO
using ProgressMeter
using ElasticsearchClient
using CSV

DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = true

# walk = SearchRequestProcessor.SimilarQueries.build_forward_walk(Int32(102)); nothing

# JLSO.save(SearchRequestProcessor.SimilarQueries.FORWARD_WALK_FILE_PATH, :walk => walk)

walk = JLSO.load(SearchRequestProcessor.SimilarQueries.FORWARD_WALK_FILE_PATH)[:walk]; nothing
walk.iters = 12

os_client = ElasticsearchClient.Client(verbose=0, deserializer=identity)
os_client.verified = true

SearchRequestProcessor.SimilarQueries.create_queries_index(os_client, walk)

query = "definition of nucleus biology"

os_client = ElasticsearchClient.Client(verbose=0)
SearchRequestProcessor.SimilarQueries.find_similars(query, os_client, walk, 0.01)

Threads.nthreads()
os_client = ElasticsearchClient.Client(verbose=0)
msmarco_queries = CSV.File("dev/data/docv2_train_queries.tsv", header=[:ID, :QUERY]).QUERY |> Vector
estimated_msmarco_queries = SearchRequestProcessor.SimilarQueries.estimate_queries(os_client, msmarco_queries)
filtered_estimated_msmarco_queries = filter(estimated_msmarco_queries) do (query, score)
    score > 20 && length(query) < 100
end

aol_queries = collect(keys(walk.query_to_vertex_id)) .|> String
estimated_aol_queries = SearchRequestProcessor.SimilarQueries.estimate_queries(os_client, aol_queries)
filtered_estimated_aol_queries = filter(estimated_aol_queries) do (query, score)
    score > 12 && length(query) < 100
end

SearchRequestProcessor.SimilarQueries.create_queries_index(
    os_client,
    filtered_estimated_msmarco_queries,
    SearchRequestProcessor.SimilarQueries.MSMARCO_INDEX_NAME
)

SearchRequestProcessor.SimilarQueries.create_queries_index(
    os_client,
    filtered_estimated_aol_queries,
    SearchRequestProcessor.SimilarQueries.INDEX_NAME
)

query = "who developed the concept of a single element to explain how chemistry works"

os_client = ElasticsearchClient.Client(verbose=1)
SearchRequestProcessor.SimilarQueries.find_similars(query, os_client, walk, 0.01)

