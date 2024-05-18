using SearchRequestProcessor
using SearchRequestProcessor.Evaluation

SearchRequestProcessor.Evaluation.prepare_full_text_index(
    SearchRequestProcessor.FullTextSearch.INDEX_NAME,
    "full_text_index_settings.json"
)
