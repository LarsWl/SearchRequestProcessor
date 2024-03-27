using Memoize
using JSON3

const DEFAULT_TRANSFMORMERS_DIR = "var/models"
const CONFIGS_DIR = "var/configs"
const TRANSFORMER_NAMES_MAP = Dict(
  TransformerNames.MINILM_ONNX_L12_DEFAULT => "minilm_onnx_L12_base.json",
  TransformerNames.MINILM_L12_DEFAULT => "minilm_L12_base.json"
)

mutable struct TransformerConfig
  inference_type::AbstractString
  name::AbstractString
  version::AbstractString
end
StructTypes.StructType(::Type{TransformerConfig}) = StructTypes.Struct()

get_transformer() = 
  resolve_config(TransformerNames.MINILM_ONNX_L12_DEFAULT) |> 
  load_transformer

@memoize memoized_transformer() = get_transformer()

function resolve_config(transformer_name::Symbol)
  config_filename = get(TRANSFORMER_NAMES_MAP, transformer_name, nothing)

  isnothing(config_filename) && throw(ArgumentError("config $transformer_name not exist"))

  joinpath(CONFIGS_DIR, config_filename) |>
  read |>
  String |>
  data -> JSON3.read(data, TransformerConfig)
end

function resolve_transformer_type(config::TransformerConfig)
  if config.inference_type == inference_type(MiniLMOnnxTransformer)
    MiniLMOnnxTransformer
  else
    error("Config error: Unknown inference type")
  end
end

load_transformer(config::TransformerConfig) = resolve_transformer_type(config)(config)
transformers_dir() = get(ENV, "TRANSFORMERS_DIR", DEFAULT_TRANSFMORMERS_DIR)
