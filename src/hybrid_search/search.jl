using DebugDataWriter

using ElasticsearchClient
using ElasticsearchClient: client as ElasticClient
using ..Chunks

const CHUNKS_PER_REQUEST_DOCUMENT = 5
const TOP_K = 20

function search(os_client::ElasticClient, query::String, size=25)
  chat_api = OpenAIChatAPI()
  openai_embeddings = Chunks.OpenAIEmbeddingsAdapter()

  tries = 0
  success = false
  general_topics, specific_topics, keywords, intentions = String[], String[], String[], String[]
  log_data = nothing

  while !success && tries < 3
    tries += 1

    general_topics, specific_topics, intentions, keywords =
      try
        log_data = extract_topics_and_keywords_from_query(query, chat_api)
        success = true

        log_data
      catch e
        @error e

        (String[], String[], String[], String[])
      end
  end

  log

  @debug_output get_debug_id("hybrid_search") "HybridSearch" log_data

  docs = retrieve_documents(
    os_client,
    openai_embeddings,
    query,
    general_topics,
    specific_topics,
    intentions,
    keywords,
    size
  )

  Iterators.take(map(doc -> doc["_source"]["metadata"]["document_id"], docs), size) |> collect
end

function extract_topics_and_keywords_from_query(query::AbstractString, chat_api)::NamedTuple
  response = 
      do_chat(
          chat_api,
          "User requested web search results with this query: $query" *
            "Give me a list of general topics closely related to what a user requested by this query, that can be used to improve search precision and recall" *
            "Give me a list of specific topics closely related to what a user requested by this query, that can be used to improve search precision and recall" *
            "Give me a list of important keywords from this query, that can be used to improve search precision and recall. Avoid common words in keywords, extract only keywords specific for this query" *
            "Give me a list of user intentions covered by this query",
          [
              "Provide short answer as a JSON object with four keys: specific_topics, general_topics, keywords, intentions. Specific topics, general topics, keywords and intentions must be represented as arrays of strings.",
              "Give from one to three general topics",
              "Give from one to three specific topics",
              "Give from one to three user intentions",
          ],
          json_response=true
      ).content |>
      JSON.parse

  get!(() -> String[], response, "specific_topics")
  get!(() -> String[], response, "general_topics")
  get!(() -> String[], response, "keywords")
  
  (
      general_topics=convert(Vector{String}, string.(response["general_topics"])),
      specific_topics=convert(Vector{String}, string.(response["specific_topics"])),
      intentions=convert(Vector{String}, string.(response["intentions"])),
      keywords=convert(Vector{String}, string.(response["keywords"]))
  )
end

function retrieve_documents(
  os_client::ElasticClient,
  adapter::Chunks.OpenAIEmbeddingsAdapter,
  query::AbstractString,
  general_topics::Vector{<: AbstractString},
  specific_topics::Vector{<: AbstractString},
  intentions::Vector{<: AbstractString},
  keywords::Vector{<: AbstractString},
  size::Integer
)
  tries = 0
  success = false
  opensearch_query = nothing

  while !success && tries < 3
    tries += 1
    opensearch_query =
      try
        q = build_opensearch_query(adapter, query, general_topics, specific_topics, intentions, keywords, size)
        success = true

        q
      catch e
        @error e

        nothing
      end
  end

  isnothing(opensearch_query) && throw(ErrorException("failed to build query"))

  response = ElasticsearchClient.search(os_client, index=INDEX_NAME, body=opensearch_query).body

  ids = unique(hit -> hit["_source"]["metadata"]["document_id"], collect(Iterators.take(response["hits"]["hits"], size)))

  if length(ids) < size
    @warn "Response not full: $(length(ids))"
  end

  ids
end

function build_opensearch_query(adapter, query, general_topics, specific_topics, intentions, keywords, size)
  extended_query = "User query: $query.\nImportant keywords: $keywords.\n Related General Topics: $(join(general_topics, ",")). \n Related Specific Topics: $(join(specific_topics, ",")). User search intentions: $(join(intentions, ","))"

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
          map(t -> build_match_query(t, 0.3), specific_topics)...,
          map(t -> build_match_query(t, 0.3), intentions)...,
        ]
      )
    )
  )
end

function build_match_query(query, boost)
  Dict(
    :multi_match => Dict(
      :type => :best_fields,
        :fields => [
          "text",
          "text.stemmed"
        ],
        :query => query,
        :boost => boost
      )
  )
end
