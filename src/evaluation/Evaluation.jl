module Evaluation

using CSV
using ElasticsearchClient
using ElasticsearchClient: Client as ElasticClient
using Statistics
using ProgressMeter
using BenchmarkTools
using JSON

include("reading_dataset.jl")
include("prepare_index.jl")

const DOCUMENT_TOP100_PATH = "dev/data/2023_passage_top100.txt"
const TEST_QUERIES_PATH = "dev/data/2023_queries.tsv"
const K = 25

function read_correct_document_ids()
  CSV.File(DOCUMENT_TOP100_PATH, header = [:QID, :Q0, :DOC_ID, :RANK, :SCORE, :RUNSTRING]).DOC_ID |>
  unique |>
  sort .|>
  String
end

function evaluate_search(search_func::Function)
  test_queries = CSV.File(TEST_QUERIES_PATH, header = [:ID, :QUERY])
  test_rels = CSV.File(DOCUMENT_TOP100_PATH, header = [:QID, :Q0, :DOC_ID, :RANK, :SCORE, :RUNSTRING])

  os_client = ElasticClient(verbose=0)

  results = Dict()

  @showprogress for query_row in test_queries
    r_precision_task = @async calc_r_precision_and_ndcg(search_func, os_client, query_row, test_rels)
    # precison_at_k_task = @async calc_precison_at_k(search_func, os_client, K, query_row, test_rels)

    wait(r_precision_task)
    #wait(precison_at_k_task)

    results[query_row.QUERY] = Dict(
      :r_precision => r_precision_task.result.r_precision,
      :ndcg_10 => r_precision_task.result.ndcg_10,
      :ndcg_20 => r_precision_task.result.ndcg_20,
      :ndcg_100 => r_precision_task.result.ndcg_100,
      #:precison_at_k => precison_at_k_task.result
    )
  end

  avg_r_precision = mean(v -> v[:r_precision], collect(values(results)))
  avg_ndcg_10 = mean(v -> v[:ndcg_10], collect(values(results)))
  avg_ndcg_20 = mean(v -> v[:ndcg_20], collect(values(results)))
  avg_ndcg_100 = mean(v -> v[:ndcg_100], collect(values(results)))
  #avg_precison_at_k = mean(v -> v[:precison_at_k], collect(values(results)))

  Dict(
    :results => results,
    :avg_ndcg_10 => avg_ndcg_10,
    :avg_ndcg_20 => avg_ndcg_20,
    :avg_ndcg_100 => avg_ndcg_100,
    :avg_r_precision => avg_r_precision,
    # :avg_precison_at_k => avg_precison_at_k
  )
end


function calc_r_precision_and_ndcg(search_func::Function, os_client, query_row, test_rels)
  gold_results = filter(rel -> rel.QID == query_row.ID, test_rels)
  gold_result_ids = getproperty.(gold_results, :DOC_ID)

  results = search_func(os_client, query_row.QUERY, length(gold_result_ids))
  relevant_results = filter(res -> res in gold_result_ids, results)

  R_precision = length(relevant_results) / length(gold_results)

  (
    r_precision=R_precision, 
    ndcg_10 = ndcg_p(results, gold_results, 10),
    ndcg_20 = ndcg_p(results, gold_results, 20),
    ndcg_100 = ndcg_p(results, gold_results, 100)
  )
end

function calc_precison_at_k(search_func::Function, os_client, k, query_row, test_rels)
  results = search_func(os_client, query_row.QUERY, k)

  gold_results = filter(rel -> rel.QID == query_row.ID, test_rels) .|> row -> row.DOC_ID
  relevant_results = filter(res -> res in gold_results, results)

  length(relevant_results) / k
end

function ndcg_p(results, gold_results, p)
  length(results) == 0 && return 0.0

  idcg_p =
    sort(gold_results, by=r -> r.RANK) |>
    gold_results ->
      sum(gold_results[begin:p]) do res
        (2 ^ rel_from_rank(res.RANK) - 1) / (log2(res.RANK + 1))
      end
  
  dcg_p =
    sum(enumerate(collect(Iterators.take(results, p)))) do (index, res)
      gold_res_index = findfirst(gr -> gr.DOC_ID == res, gold_results)
      relevance =
        if isnothing(gold_res_index)
          0
        else
          rel_from_rank(gold_results[gold_res_index].RANK)
        end

        (2 ^ relevance - 1) / (log2(index + 1))
    end

  return dcg_p / idcg_p
end

function rel_from_rank(rank)
  11 - ((rank / 20.0) |> ceil)
end

end
