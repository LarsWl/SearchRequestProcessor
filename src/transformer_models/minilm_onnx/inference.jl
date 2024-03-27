using TextEncodeBase

function inference_transformer(transformer::MiniLMOnnxTransformer, text::AbstractString)
    tokenize_onnx(transformer, text) |>
    transformer.model |> # calculating forward pass and getting embeddings from the last hidden layer
    model_result -> permutedims(model_result["last_hidden_state"], (3, 2, 1)) # permute onnx embeddings
end

"""
Building input parameters for onnx model from input text


"""
function tokenize_onnx(transformer::MiniLMOnnxTransformer, text::AbstractString)
    ohe = encode(transformer.encoder, text).token

    # getting tokens indices in Vocabulary
    len = size(ohe)[2]
    reduced_len = min(len, transformer.max_sequence_length)
    indices = map(1:reduced_len) do i
        argmax(ohe[:, i])
    end

    # reducing each index by 1, since onnx model 
    # uses Python indexation (first index is zero)
    indices .-= 1

    # reshaping indices into 1xn matrix 
    input = reshape(indices, (1, length(indices)))

    # setting mask and token_type_ids
    mask = ones(Int64, 1, length(indices))
    type = zeros(Int64, 1, length(indices))

    # building dictionary for onnx model input parameters
    Dict("input_ids" => input, "attention_mask" => mask, "token_type_ids" => type)
end
