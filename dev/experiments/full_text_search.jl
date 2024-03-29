using SearchRequestProcessor
using ElasticsearchClient

os_client = ElasticsearchClient.Client(verbose=1)
query = "code of ethics for teachers the state"

SearchRequestProcessor.FullTextSearch.search(os_client, query)

using JSON

println()
