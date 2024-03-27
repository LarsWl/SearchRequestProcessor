module Chunks

include("models/document.jl")
include("models/document_chunk.jl")
include("models/document_chunk_metadata.jl")
include("embedding_adapters/abstract_adapter.jl")
include("embedding_adapters/transformer_adapater.jl")
include("embedding_adapters/openai_adapter.jl")
include("create_chunks.jl")

using UUIDs

using BytePairEncoding: gpt2_codemap, GPT2Tokenization, Merge, BPE, BPETokenization
using TextEncodeBase: TextEncodeBase, FlatTokenizer, CodeNormalizer, Sentence, getvalue, CodeUnMap
using HuggingFaceApi

# Global variables
GPT2_TOKENIZER = let
    url = HuggingFaceURL("gpt2", "merges.txt")
    file = HuggingFaceApi.cached_download(url)
    bpe = BPE(file)
    FlatTokenizer(CodeNormalizer(BPETokenization(GPT2Tokenization(), bpe), gpt2_codemap()))

    #     tiktoken.get_encoding(
    #     "cl100k_base"
    # )  # The encoding scheme to use for tokenization
end



end
