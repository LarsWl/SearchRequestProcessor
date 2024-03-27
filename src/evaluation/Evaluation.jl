module Evaluation

using CSV
using ElasticsearchClient
using ElasticsearchClient: Client as ElasticClient
using Statistics

include("reading_dataset.jl")
include("prepare_index.jl")

const DOCUMENT_TOP100_PATH = "dev/data/2023_document_top100.txt"
const TEST_QUERIES_PATH = "dev/data/2023_queries.tsv"

function read_correct_document_ids()
  CSV.File(DOCUMENT_TOP100_PATH, header = [:QID, :Q0, :DOC_ID, :RANK, :SCORE, :RUNSTRING]).DOC_ID |>
  unique |>
  sort .|>
  String
end

function evaluate_search(search_func::Function)
  test_queries = CSV.File(TEST_QUERIES_PATH, header = [:ID, :QUERY])
  test_rels = CSV.File(DOCUMENT_TOP100_PATH, header = [:QID, :Q0, :DOC_ID, :RANK, :SCORE, :RUNSTRING])

  os_client = ElasticClient(verbose=1)

  results = Dict()

  for query_row in test_queries[begin:begin+15]
    r_precision_task = @async calc_r_precision(search_func, os_client, query_row, test_rels)
    recall_task = @async calc_recall(search_func, os_client, query_row, test_rels)

    wait(r_precision_task)
    wait(recall_task)

    results[query_row.QUERY] = Dict(
      :r_precision => r_precision_task.result,
      :recall => recall_task.result
    )
  end

  avg_r_precision = mean(v -> v[:r_precision], collect(values(results)))
  avg_recall = mean(v -> v[:recall], collect(values(results)))

  Dict(
    :results => results,
    :avg_r_precision => avg_r_precision,
    :avg_recall => avg_recall
  )
end



function calc_r_precision(search_func::Function, os_client, query_row, test_rels)
  gold_results = filter(rel -> rel.QID == query_row.ID, test_rels) .|> row -> row.DOC_ID

  results = search_func(os_client, query_row.QUERY, length(gold_results))
  relevant_results = filter(res -> res in gold_results, results)

  length(relevant_results) / length(gold_results)
end

function calc_recall(search_func::Function, os_client, query_row, test_rels)
  results = search_func(os_client, query_row.QUERY, 1000)

  gold_results = filter(rel -> rel.QID == query_row.ID, test_rels) .|> row -> row.DOC_ID
  relevant_results = filter(res -> res in gold_results, results)

  length(relevant_results) / length(gold_results)
end

end
