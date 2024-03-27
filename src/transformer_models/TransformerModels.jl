module TransformerModels

using StructTypes
using LinearAlgebra

export vectorize_sentence, matricize_document, vectorize_document
export load_transformer_files
export get_transformer

const TRANSFORMERS_S3_FOLDER = "transformer-models"

abstract type AbstractTransformer end

include("transformer_names.jl")
include("context_loader.jl")
include("vectorization.jl")
include("minilm_onnx/minilm_onnx.jl")

end # module TransformerModels
