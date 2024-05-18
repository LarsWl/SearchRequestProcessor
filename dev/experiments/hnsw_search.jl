using SearchRequestProcessor
using SearchRequestProcessor.Chunks
using SearchRequestProcessor.Evaluation
using ElasticsearchClient
using JSON3

SearchRequestProcessor.Evaluation.prepare_hnsw_search_index(
  SearchRequestProcessor.HnswSearch.create_index,
  SearchRequestProcessor.Chunks.TransformerEmbeddingsAdapter(),
  SearchRequestProcessor.HnswSearch.INDEX_NAME
)
