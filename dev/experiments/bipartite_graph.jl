using SearchRequestProcessor
using DebugDataWriter
using Graphs
using JLSO
using ProgressMeter
using ElasticsearchClient

DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = true

# walk = SearchRequestProcessor.SimilarQueries.build_forward_walk(Int32(102)); nothing

# JLSO.save(SearchRequestProcessor.SimilarQueries.FORWARD_WALK_FILE_PATH, :walk => walk)

walk = JLSO.load(SearchRequestProcessor.SimilarQueries.FORWARD_WALK_FILE_PATH)[:walk]; nothing
walk.iters = 12

os_client = ElasticsearchClient.Client(verbose=0, deserializer=identity)
os_client.verified = true

SearchRequestProcessor.SimilarQueries.create_queries_index(os_client, walk)

query = "living in berlin"

os_client = ElasticsearchClient.Client(verbose=0)
SearchRequestProcessor.SimilarQueries.find_similars(query, os_client, walk, 0.01)
