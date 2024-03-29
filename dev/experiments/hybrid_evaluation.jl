using SearchRequestProcessor
using SearchRequestProcessor.Evaluation
using SearchRequestProcessor.FullTextSearch
using JSON
using BenchmarkTools
using CSV
using DebugDataWriter

hybrid_search_results = Evaluation.evaluate_search(SearchRequestProcessor.HybridSearch.search)
open(f -> write(f, JSON.json(hybrid_search_results, 2)), "results/hybrid_search_results.json", "w")