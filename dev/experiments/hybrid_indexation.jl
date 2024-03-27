using SearchRequestProcessor
using SearchRequestProcessor.Chunks
using SearchRequestProcessor.Evaluation
using ElasticsearchClient
using JSON3

SearchRequestProcessor.Evaluation.prepare_hnsw_search_index(
  SearchRequestProcessor.HybridSearch.create_index,
  SearchRequestProcessor.Chunks.OpenAIEmbeddingsAdapter(),
  SearchRequestProcessor.HybridSearch.INDEX_NAME,
  800
)
