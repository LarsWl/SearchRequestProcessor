using SearchRequestProcessor
using SearchRequestProcessor.Evaluation
using SearchRequestProcessor.FullTextSearch
using JSON
using BenchmarkTools
using CSV
using DebugDataWriter
using ElasticsearchClient

DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = false

baseline_results = Evaluation.evaluate_search(FullTextSearch.baseline_search)
open(f -> write(f, JSON.json(baseline_results, 2)), "results/baseline_results.json", "w")

full_text_results = Evaluation.evaluate_search(FullTextSearch.search)
open(f -> write(f, JSON.json(full_text_results, 2)), "results/full_text_search_results.json", "w")

hnsw_search_results = Evaluation.evaluate_search(SearchRequestProcessor.HnswSearch.search)
open(f -> write(f, JSON.json(hnsw_search_results, 2)), "results/hnsw_search_results.json", "w")

hybrid_search_results = Evaluation.evaluate_search(SearchRequestProcessor.HybridSearch.search)
open(f -> write(f, JSON.json(hybrid_search_results, 2)), "results/hybrid_search_results.json", "w")

global test_queries = CSV.File(Evaluation.TEST_QUERIES_PATH, header = [:ID, :QUERY]).QUERY
global os_client = ElasticsearchClient.Client(verbose=0)

DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = false

@benchmark FullTextSearch.baseline_search(os_client, rand(test_queries)) samples=100 evals=3 seconds=300
@benchmark FullTextSearch.search(os_client, rand(test_queries)) samples=100 evals=3 seconds=300
@benchmark SearchRequestProcessor.HnswSearch.search(os_client, rand(test_queries)) samples=100 evals=3 seconds=300
@benchmark SearchRequestProcessor.HybridSearch.search(os_client, rand(test_queries)) samples=100 evals=2 seconds=300

