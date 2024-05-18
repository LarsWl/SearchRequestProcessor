using SearchRequestProcessor
using SearchRequestProcessor.Evaluation

SearchRequestProcessor.Evaluation.prepare_full_text_index(
    SearchRequestProcessor.FullTextSearch.BASELINE_INDEX_NAME,
    "baseline_index_settings.json"
)
