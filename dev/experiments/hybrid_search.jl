using SearchRequestProcessor
using SearchRequestProcessor.Chunks
using SearchRequestProcessor.Evaluation
using ElasticsearchClient
using DebugDataWriter

os_client = ElasticsearchClient.Client(verbose=1)
DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = true

query = "is eucalyptus oil good for allergies"

res = SearchRequestProcessor.HybridSearch.search(os_client, query)
