using DebugDataWriter

using ElasticsearchClient
using ElasticsearchClient: client as ElasticClient
using ..Chunks

const CHUNKS_PER_REQUEST_DOCUMENT = 5
const TOP_K = 25

function search(os_client::ElasticClient, query::String, size=25)
  chat_api = OpenAIChatAPI()
  openai_embeddings = Chunks.OpenAIEmbeddingsAdapter()

  topics, intentions =
    try
      extract_topics_and_intentions_from_query(query, chat_api)
    catch e
      @error e

      (String[], String[])
    end 
    

  @debug_output get_debug_id("hybrid_search") "HybridSearch" "Query: $query.\nExtracted topics: $topics.\n" * "Extracted intentions: $intentions\n"

  docs = retrieve_documents(
    os_client,
    openai_embeddings,
    query,
    topics, 
    intentions,
    size
  )

  Iterators.take(map(doc -> doc["_source"]["metadata"]["document_id"], docs), size) |> collect
end

function extract_topics_and_intentions_from_query(query::AbstractString, chat_api)::NamedTuple
  response = 
      do_chat(
          chat_api,
          "User requested web search results with this query: $query" *
            "Give me a list of topics closely related to what a user requested by this query" *
            "Give me a list of user intentions covered by this query",
          [
              "Provide short answer as a JSON object with two keys: topics, intentions. Topics and intentions must be represented as arrays of strings.",
              "Use the minimum number of topics necessary, combining topics with similar meaning and content into more general topics.",
              "Return from one to two user intentions and make them explicit",
          ],
          json_response=true
      ).content |>
      JSON.parse

  get!(() -> String[], response, "topics")
  get!(() -> String[], response, "intentions")
  
  (
      topics=convert(Vector{String}, string.(response["topics"])),
      intentions=convert(Vector{String}, string.(response["intentions"]))
  )
end

function retrieve_documents(
  os_client::ElasticClient,
  adapter::Chunks.OpenAIEmbeddingsAdapter,
  query::AbstractString,
  topics::Vector{<: AbstractString},
  intentions::Vector{<: AbstractString},
  size::Integer
)
  results = AbstractDict[]

  for intention in intentions
    opensearch_query =
      try
        build_opensearch_query(adapter, query, topics, intention, size)
      catch e 
        nothing
      end

    isnothing(opensearch_query) && continue

    response = ElasticsearchClient.search(os_client, index=INDEX_NAME, body=opensearch_query).body

    append!(results, response["hits"]["hits"])
  end

  results = sort(results, by=hit -> hit["_score"], rev=true)

  foreach(results) do hit
    hit["_source"]["metadata"]["document_id"] = replace(hit["_source"]["metadata"]["document_id"], r"_title" => "")
  end

  unique(hit -> hit["_source"]["metadata"]["document_id"], results)
end

function build_opensearch_query(adapter, query, topics, intention, size)
  extended_query = "User query: $query.\nUser intention: $intention.\nRelated Topics: $(join(topics, ","))."

  Dict(
    :_source => ["text", "metadata"],
    :size => max(size * CHUNKS_PER_REQUEST_DOCUMENT, 10_000),
    :query => Dict(
      :bool => Dict(
        :should => [
          Dict(
            :knn => Dict(
              :embedding => Dict(
                :vector => Chunks.calculate_embeddings(adapter, extended_query),
                :k => TOP_K,
                :boost => 1  
              )
            )
          ),
          Dict(
            :bool => Dict(
              :must => [
                Dict(
                  :wildcard => Dict(
                    Symbol("_id.keyword") => Dict(
                      :value => "*_title_*"
                    )
                  )
                ),
                Dict(
                  :knn => Dict(
                    :embedding => Dict(
                      :vector => Chunks.calculate_embeddings(adapter, extended_query),
                      :k => TOP_K,
                      :boost => 2
                    )
                  )
                )
              ]
            )
          )
        ]
      )
    )
  )
end
