using CSV
using Graphs, SimpleWeightedGraphs
using Dates
using ProgressMeter
using JLSO
using SparseArrays
using Suppressor
using DebugDataWriter
using Memoize

const DATE_FORMAT = "y-m-d H:M:S"
const SELF_TRANSITION_PROB = 0.9
const FORWARD_WALK_FILE_PATH = "dev/data/forward_walk.jlso"

const TOO_COMMON_QUERIES = [
  :google, :-, :ebay, 
  Symbol("google.com"), :yahoo, Symbol("yahoo.com"),
  :ikea, :myspace, Symbol("myspace.com"),
  :mapquest, Symbol("map quest"), Symbol("www.yahoo.com"),
  Symbol("www.google.com"), :msn, Symbol("msn.com")
]

logs_file_path(part) = "dev/data/AOL-user-ct-collection/user-ct-test-collection-$part.txt"
const DATASET_PARTS =
  range(1, 4) |> 
  collect .|> 
  string |> 
  ids -> map(id -> length(id) == 1 ? "0" * id : id, ids)

struct BackwardRandomWalk
  graph
  iters
  adjency_matrix
  Z
end

mutable struct ForwardRandomWalk
  graph
  iters
  adjency_matrix
  query_to_vertex_id
  doc_to_vertex_id
end

@memoize memozied_forward_walk() = begin
  walk = JLSO.load(FORWARD_WALK_FILE_PATH)[:walk]
  walk.iters = 12

  walk
end

function build_forward_walk(iters::Int32)::ForwardRandomWalk
  query_to_node_id = Dict{Symbol, Int32}()
  doc_to_node_id = Dict{Symbol, Int32}()

  common_clicks_count = Dict{Int32, Int32}()
  clicks_count = Dict{Tuple{Int32, Int32}, Int32}()

  node_id_to_outdegree = Dict{Int32, Int32}()
  node_id_to_indegree = Dict{Int32, Int32}()

  init_node_id(node_id) = begin
    get!(common_clicks_count, node_id, 0)
    get!(node_id_to_indegree, node_id, 0)
    get!(node_id_to_outdegree, node_id, 0)
  end
  
  @info "Assign node ids"
  for part_number in DATASET_PARTS
    logs = CSV.File(logs_file_path(part_number))

    @info "Process part: $part_number"
    @showprogress for row_index in eachindex(logs)
      row = logs[row_index]
      query = Symbol(lowercase(row.Query))

      in(query, TOO_COMMON_QUERIES) && continue
    
      query_id = 
        get!(query_to_node_id, query) do
          length(query_to_node_id) + length(doc_to_node_id) + 1
        end

      init_node_id(query_id)
      
      # There is click for query
      if !ismissing(row.ClickURL)
        doc = Symbol(row.ClickURL)
    
        doc_id =
          get!(doc_to_node_id, doc) do
            length(query_to_node_id) + length(doc_to_node_id) + 1
          end

        init_node_id(doc_id)

        query_to_doc_click_id = (query_id, doc_id)

        # It is first click for query - document pair
        if get!(clicks_count, query_to_doc_click_id, 0) == 0
          node_id_to_outdegree[query_id] += 1
          node_id_to_indegree[doc_id] += 1
        end

        common_clicks_count[query_id] += 1
        clicks_count[query_to_doc_click_id] += 1
      end

      # Check is this query reformulation from prev
      # First query in logs, so don't check prev query
      row_index == 1 && continue

      prev_log = logs[row_index - 1]
      prev_query = Symbol(lowercase(prev_log.Query))

      in(prev_query, TOO_COMMON_QUERIES) && continue

      if !ismissing(prev_log.ClickURL)
        prev_doc = Symbol(prev_log.ClickURL)

        if is_same_session(prev_log, row)
          prev_doc_id = doc_to_node_id[prev_doc]
  
          doc_to_query_click_id = (prev_doc_id, query_id)
  
          get!(common_clicks_count, prev_doc_id, 0)
          
          if get!(clicks_count, doc_to_query_click_id, 0) == 0
            node_id_to_outdegree[prev_doc_id] += 1
            node_id_to_indegree[query_id] += 1
          end
  
          common_clicks_count[prev_doc_id] += 1
          clicks_count[doc_to_query_click_id] += 1
        end
      end
    end
  end

  @debug_output get_debug_id("forward_walk") "Initial nodes" "Queries: $(length(query_to_node_id)).\nDocs: $(length(doc_to_node_id)).\nClicks: $(sum(values(common_clicks_count)))"

  node_id_to_query = Dict(value => key for (key, value) in collect(query_to_node_id))
  node_id_to_doc = Dict(value => key for (key, value) in collect(doc_to_node_id))

  for i in 1:6
    # Detect and delete docs with few clicks
    detect_and_delete_nodes_with_few_clicks(
      collect(keys(node_id_to_doc)),
      node_id_to_doc,
      doc_to_node_id,
      node_id_to_indegree,
      node_id_to_outdegree,
      common_clicks_count,
      clicks_count
    )

    # Detect and delete queries with few clicks
    detect_and_delete_nodes_with_few_clicks(
      collect(keys(node_id_to_query)),
      node_id_to_query,
      query_to_node_id,
      node_id_to_indegree,
      node_id_to_outdegree,
      common_clicks_count,
      clicks_count
    )

    @debug_output get_debug_id("forward_walk") "Cleaned nodes" "Queries: $(length(query_to_node_id)). Docs: $(length(doc_to_node_id)). Clicks: $(sum(values(common_clicks_count)))"
    @debug_output get_debug_id("forward_walk") "clicks_count" clicks_count
  end

  query_to_vertex_id = Dict{Symbol, Int32}()
  doc_to_vertex_id = Dict{Symbol, Int32}()

  for query in keys(query_to_node_id)
    query_to_vertex_id[query] = length(query_to_vertex_id) + 1
  end
  
  for doc in keys(doc_to_node_id)
    doc_to_vertex_id[doc] = length(query_to_vertex_id) + length(doc_to_vertex_id) + 1
  end

  # Building graph
  graph = @suppress(SimpleWeightedDiGraph{Int32, Float32}(length(query_to_vertex_id) + length(doc_to_vertex_id)))

  @info "Adding queries to graph"
  @showprogress for vertex_id in values(query_to_vertex_id)
    if !add_edge!(graph, vertex_id, vertex_id, SELF_TRANSITION_PROB)
      throw(ErrorException("Can't add edge"))
    end
  end
  
  @info "Adding docs to graph"
  @showprogress for vertex_id in values(doc_to_vertex_id)
    if !add_edge!(graph, vertex_id, vertex_id, SELF_TRANSITION_PROB)
      throw(ErrorException("Can't add edge"))
    end
  end

  @info "Adding weighted edges"
  @showprogress for (click_id, click_count) in collect(clicks_count)
    src_node_id, dest_node_id = click_id

    src_node_id_to_node = haskey(node_id_to_query, src_node_id) ? node_id_to_query : node_id_to_doc
    dest_node_id_to_node = haskey(node_id_to_query, dest_node_id) ? node_id_to_query : node_id_to_doc

    src_node = get(src_node_id_to_node, src_node_id, nothing)
    dest_node = get(dest_node_id_to_node, dest_node_id, nothing)

    (isnothing(src_node) || isnothing(dest_node)) && continue

    src_vertex_id = get(query_to_vertex_id, src_node) do 
      get(doc_to_vertex_id, src_node, nothing)
    end

    dest_vertex_id = get(doc_to_vertex_id, dest_node) do 
      get(query_to_vertex_id, dest_node, nothing)
    end

    (isnothing(src_vertex_id) || isnothing(dest_vertex_id)) && continue

    transition_weight = (1 - SELF_TRANSITION_PROB) * (click_count / common_clicks_count[src_node_id])
  
    if !add_edge!(graph, src_vertex_id, dest_vertex_id, transition_weight)
      throw(ErrorException("Can't add edge"))
    end
  end

  @suppress(ForwardRandomWalk(graph, iters, adjacency_matrix(graph), query_to_vertex_id, doc_to_vertex_id))
end

function detect_and_delete_nodes_with_few_clicks(
  node_ids_to_check::Vector{Int32},
  node_id_to_node::Dict{Int32, Symbol},
  node_to_node_id::Dict{Symbol, Int32},
  node_id_to_indegree::Dict{Int32, Int32},
  node_id_to_outdegree::Dict{Int32, Int32},
  common_clicks_count::Dict{Int32, Int32},
  clicks_count::Dict{Tuple{Int32, Int32}, Int32}
)
  nodes_with_few_clicks =
    filter(node_ids_to_check) do node_id
      indegree = node_id_to_indegree[node_id]
      outdegree = node_id_to_outdegree[node_id]

      indegree + outdegree <= 4 || outdegree < 2
    end |> sort

  @info "Nodes to delete: $(length(nodes_with_few_clicks))"

  for node_id in nodes_with_few_clicks
    node = node_id_to_node[node_id]
  
    delete!(node_to_node_id, node)
    delete!(node_id_to_node, node_id)
    delete!(node_id_to_indegree, node_id)
    delete!(node_id_to_outdegree, node_id)
    delete!(common_clicks_count, node_id)
  end

  for click_id in keys(clicks_count)
    src_node_id, dest_node_id = click_id
    count = clicks_count[click_id]

    if insorted(dest_node_id, nodes_with_few_clicks)
      delete!(clicks_count, click_id)
      common_clicks_count[src_node_id] -= count
      node_id_to_outdegree[src_node_id] -= 1
    end

    if insorted(src_node_id, nodes_with_few_clicks)
      delete!(clicks_count, click_id)
      node_id_to_indegree[dest_node_id] -= 1
    end
  end
end


function is_same_session(log_a, log_b)
  log_a.AnonID == log_b.AnonID || return false

  log_a_date = DateTime(log_a.QueryTime, DATE_FORMAT)
  log_b_date = DateTime(log_b.QueryTime, DATE_FORMAT)

  (log_b_date - log_a_date) < Minute(15)
end

function calc_distribution(walk::ForwardRandomWalk, vertex_id)
  vj = zeros(length(walk.doc_to_vertex_id) + length(walk.query_to_vertex_id))'
  vj[vertex_id] = 1

  distr = vj * walk.adjency_matrix

  for i in 1:walk.iters - 1
    distr = distr * walk.adjency_matrix
  end

  distr'
end

function calc_distribution(walk::BackwardRandomWalk, vertex_id)
  qj = zeros(length(walk.doc_to_vertex_id) + length(walk.query_to_vertex_id))
  qj[vertex_id] = 1

  distr = walk.adjency_matrix * qj

  for i in 1:walk.iters - 1
    distr = walk.adjency_matrix * distr
  end

  distr ./ walk.Z[vertex_id]
end

# Calculations for backward walk
# iters = 22
# Z = length(vertex_id_to_node_id) |> zeros |> cu

# @showprogress for vertex_id in sort(collect(keys(vertex_id_to_node_id)))
#   Z += calc_distribution(forward_walk, vertex_id)'
# end
