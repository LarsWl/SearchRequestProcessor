using SearchRequestProcessor
using ElasticsearchClient
using JSON

println(JSON.json(SearchRequestProcessor.Evaluation.evaluate_search(SearchRequestProcessor.HnswSearch.search), 2))