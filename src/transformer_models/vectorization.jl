"""
Normalizing embeddings length


"""
normalize_embedding(embedding) = embedding / sqrt(sum(embedding .* embedding))

"""
Pooling tokens (summarization of tokens embeddings) from last hidden state
using mean pool operation.


"""
function mean_pool_embedding(embedding_matrix::AbstractArray{Float32})
    matrix_size = size(embedding_matrix)
    """
        Number of elements (tokens or sentences) is obtained as a second element of embedding matrix size.
    """
    elements_number = matrix_size[2]
    pooled_embedding = sum(embedding_matrix, dims = 2) / elements_number

    vec(pooled_embedding)
end

"""
Function for mean pooling with the subsequent normalizing ofthe embedding matrix


"""
normalize_mean_pool(embedding_matrix::AbstractArray{Float32}) =
    mean_pool_embedding(embedding_matrix) |> normalize_embedding

"""
Return a sentence embedding vector of the length of the transformer embedding length. 
Computing of sentence embedding could be done for a single string or a matrix of tokens embeddings
representing sentence. Input sentence could be preprocessed before embedding computation. In 
this case processing function should return single string.


"""
function vectorize_sentence(
    transformer::AbstractTransformer,
    sentence::AbstractString,
    pooling_method = normalize_mean_pool,
)
    embeddings_matrix = inference_transformer(transformer, sentence)
    pooling_method(embeddings_matrix)
end

vectorize_sentence(
    embedding_matrix::Array{Float32,3},
    pooling_method = normalize_mean_pool,
) = pooling_method(embedding_matrix)

"""
Computation of an embedding matrix for the set of sentences. Function allows 
computation to perform processing for the input sentences before matrix computation. 
Input text could be either a vector of senetences, single string or a vector of 
embedding matrices, representing sentences in the document. In the case of a single string 
representing the document, processing function must return a vector of strings.


"""
function matricize_document(
    trasformer::AbstractTransformer,
    document::Vector{<:AbstractString},
    pooling_method = normalize_mean_pool,
)
    sentences_embeddings = map(document) do sentence
        vectorize_sentence(trasformer, sentence, pooling_method)
    end

    hcat(sentences_embeddings...)
end

matricize_document(
    trasformer::AbstractTransformer,
    document::AbstractString,
    processing_func::Function,
    pooling_method = normalize_mean_pool,
) = matricize_document(trasformer, processing_func(document), pooling_method)

function matricize_document(
    sentences_matrices::Vector{Array{Float32,3}},
    pooling_method = normalize_mean_pool
)
    sentences_embeddings = map(sentences_matrices) do sentence_matrix
        vectorize_sentence(sentence_matrix, pooling_method)
    end

    hcat(sentences_embeddings...)
end

"""
Calculate document embedding via mean pooling


"""
vectorize_document(
    trasformer::AbstractTransformer,
    document::Vector{<:AbstractString},
    sentence_pooling_method = normalize_mean_pool,
    document_pooling_method = normalize_mean_pool,
) =
    matricize_document(trasformer, document, sentence_pooling_method) |>
    document_pooling_method

vectorize_document(
    trasformer::AbstractTransformer,
    document::AbstractString,
    processing_func::Function,
    sentence_pooling_method = normalize_mean_pool,
    document_pooling_method = normalize_mean_pool,
) =
    matricize_document(trasformer, document, processing_func, sentence_pooling_method) |>
    document_pooling_method
