using OpenAI
using DebugDataWriter

const OPENAI_EMBEDDINGS_MODEL_ID = "text-embedding-3-small"
const EMPTY_EMBEDDING_RESULT = Float64[]
const EMPTY_BATCH_EMBEDDING_RESULT = Vector{Float64}[]

struct OpenAIEmbeddingsAdapter <: AbstractEmbeddingsAdapter
  openai_secret_key::String

  OpenAIEmbeddingsAdapter() = new(get_openai_secret_key())
end

TOKENS_STATISTICS = Dict(
  :threshold => 10000,
  :total_tokens => 0
)
const TOKENS_STATISTICS_MUTEX = ReentrantLock()

get_openai_secret_key() = get(ENV, "OPENAI_SECRET_KEY", nothing)

function calculate_embeddings(adapter::OpenAIEmbeddingsAdapter, batch_texts::Vector{<:AbstractString})::Vector{Vector{Float64}}
  response = OpenAI.create_embeddings(adapter.openai_secret_key, batch_texts, OPENAI_EMBEDDINGS_MODEL_ID)

  result = EMPTY_BATCH_EMBEDDING_RESULT

  # @debug_output get_debug_id("batch_embeddings") "OpenAI" response

  response.status != 200 && return result

  collect_statistics(response)

  if (v = get(response.response, "data", nothing)) isa AbstractVector
      result = map(v) do data
          get(data, "embedding", EMPTY_EMBEDDING_RESULT)
      end
  end

  return result
end

function calculate_embeddings(adapter::OpenAIEmbeddingsAdapter, text::AbstractString)
  response = OpenAI.create_embeddings(adapter.openai_secret_key, text, OPENAI_EMBEDDINGS_MODEL_ID)
  result = EMPTY_EMBEDDING_RESULT

  # @debug_output get_debug_id("batch_embeddings") "OpenAI" response

  response.status != 200 && return result

  collect_statistics(response)

  if (v = first(get(response.response, "data", nothing))) isa AbstractDict &&
      (v = get(v, "embedding", nothing)) isa AbstractVector
      result = v
  end

  return result
end

function collect_statistics(response)
  lock(TOKENS_STATISTICS_MUTEX) do
    TOKENS_STATISTICS[:total_tokens] += response.response["usage"]["total_tokens"]

    if TOKENS_STATISTICS[:total_tokens] > TOKENS_STATISTICS[:threshold]
      @info "Processed tokens: $(TOKENS_STATISTICS[:total_tokens])"

      TOKENS_STATISTICS[:threshold] += 100000
    end
  end
end