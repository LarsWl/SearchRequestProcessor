using SearchRequestProcessor
using ElasticsearchClient
using JSON

open("results/hnsw_evaluation.json", "w") do f
    write(
        f,
        JSON.json(SearchRequestProcessor.Evaluation.evaluate_search(SearchRequestProcessor.HnswSearch.search), 2)
    )
end
