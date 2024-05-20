using SearchRequestProcessor
using SearchRequestProcessor.Chunks
using SearchRequestProcessor.Evaluation
using ElasticsearchClient
using DebugDataWriter

os_client = ElasticsearchClient.Client(verbose=1)
DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = true

query = "What are the guidelines for publishing comments on this website?"

res = SearchRequestProcessor.HybridSearch.search(os_client, query)
