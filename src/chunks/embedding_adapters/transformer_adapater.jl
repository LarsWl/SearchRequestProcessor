using ..TransformerModels

struct TransformerEmbeddingsAdapter <: AbstractEmbeddingsAdapter
  transformer::TransformerModels.AbstractTransformer

  TransformerEmbeddingsAdapter() = new(get_transformer())
end

function calculate_embeddings(
  adapter::TransformerEmbeddingsAdapter,
  batch_texts::AbstractArray{<: AbstractString}
)::Vector{Vector{<: AbstractFloat}}
  map(text -> calculate_embeddings(adapter, text), batch_texts)
end

function calculate_embeddings(
  adapter::TransformerEmbeddingsAdapter,
  text::AbstractString
)::Vector{<: AbstractFloat}
  vectorize_sentence(adapter.transformer, text)
end
