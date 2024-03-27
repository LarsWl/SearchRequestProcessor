using Flux
using ONNXRunTime
using ONNXRunTime.CAPI
using ONNXRunTime: testdatapath
using Transformers
using Transformers.TextEncoders: BertTextEncoder
using BSON
using Serialization

const DEFAULT_MINI_LM_ONNX_MAX_SEQ_LEN = 256
const MINI_LM_ONNX_S3_FOLDER = "minilm-onnx"

mutable struct MiniLMOnnxTransformer <: AbstractTransformer
    name::AbstractString
    version::AbstractString
    model::ONNXRunTime.InferenceSession
    encoder::BertTextEncoder
    max_sequence_length::Integer
end

function MiniLMOnnxTransformer(
    name,
    version,
    max_sequence_length = DEFAULT_MINI_LM_ONNX_MAX_SEQ_LEN,
)
    transformer_dir = joinpath(transformers_dir(), folder_name(MiniLMOnnxTransformer))

    !isdir(transformer_dir) && error("$transformer_dir is not a dir")

    model =
        model_file_name(MiniLMOnnxTransformer, name, version) |>
        m_file_name -> 
            joinpath(transformer_dir, m_file_name) |>
            load_inference

    encoder =
        encoder_file_name(MiniLMOnnxTransformer, name, version) |>
        e_file_name ->
            joinpath(transformer_dir, e_file_name) |>
            e_file_path -> deserialize(e_file_path)

    MiniLMOnnxTransformer(name, version, model, encoder, max_sequence_length)
end

MiniLMOnnxTransformer(config::TransformerConfig) = MiniLMOnnxTransformer(
    config.name,
    config.version,
)

model_file_name(transformer::MiniLMOnnxTransformer) =
    model_file_name(typeof(transformer), transformer.name, transformer.version)
model_file_name(::Type{MiniLMOnnxTransformer}, name, version) =
    "model-$(name)-v$version.onnx"

encoder_file_name(transformer::MiniLMOnnxTransformer) =
    encoder_file_name(typeof(transformer), transformer.name, transformer.version)
encoder_file_name(::Type{MiniLMOnnxTransformer}, name, version) =
    "encoder-$(name)-v$version.jls"

inference_type(::Type{MiniLMOnnxTransformer}) = "onnx"
folder_name(::Type{MiniLMOnnxTransformer}) = "minilm_onnx"

# For compatability with Windows I don't use joinpath
s3_path(::Type{MiniLMOnnxTransformer}, file_name) =
    "$(TRANSFORMERS_S3_FOLDER)/$(MINI_LM_ONNX_S3_FOLDER)/$(file_name)"
