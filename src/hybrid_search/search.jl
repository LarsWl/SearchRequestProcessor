using DebugDataWriter

using ElasticsearchClient
using ElasticsearchClient: client as ElasticClient
using ..Chunks

const CHUNKS_PER_REQUEST_DOCUMENT = 5
const TOP_K = 5

function search(os_client::ElasticClient, query::String, size=25)
  chat_api = OpenAIChatAPI()
  openai_embeddings = Chunks.OpenAIEmbeddingsAdapter()

  tries = 0
  success = false
  topics, intentions = String[], String[]

  while !success && tries < 3
    tries += 1

    topics, intentions =
      try
        res = extract_topics_and_intentions_from_query(query, chat_api)
        success = true

        res
      catch e
        @error e

        (String[], String[])
      end
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
  tries = 0
  success = false
  opensearch_query = nothing

  while !success && tries < 3
    tries += 1
    opensearch_query =
      try
        q = build_opensearch_query(adapter, query, topics, intentions, size)
        success = true

        q
      catch e
        @error e

        nothing
      end
  end

  isnothing(opensearch_query) && throw(ErrorException("failed to build query"))

  response = ElasticsearchClient.search(os_client, index=INDEX_NAME, body=opensearch_query).body

  unique(hit -> hit["_source"]["metadata"]["document_id"], collect(Iterators.take(response["hits"]["hits"], size)))
end

function build_opensearch_query(adapter, query, topics, intentions, size)
  extended_query = "User query: $query.\nUser intentions: $intentions.\n Related Topics: $(join(topics, ","))."

  Dict(
    :_source => ["text", "metadata"],
    :size => size * 2,
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
          build_match_query(query, 2),
          map(t -> build_match_query(t, 0.2), topics)...,
        ]
      )
    )
  )
end

function build_match_query(query, boost)
  Dict(
    :match => Dict(
      :text => Dict(
        :query => query,
        :boost => boost
      )
    )
  )
end
