using SearchRequestProcessor
using DebugDataWriter
using JLSO
using ElasticsearchClient

DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = true

# SearchRequestProcessor.Abbreviations.parse_wikidata_abbreviations()

existing_abbrs = SearchRequestProcessor.Abbreviations.parse_new_abbreviations()

os_client = ElasticsearchClient.Client(verbose=0)
abbreviations_collection = SearchRequestProcessor.Abbreviations.score_definitions(os_client, existing_abbrs)

JLSO.save(SearchRequestProcessor.Abbreviations.COLLECTION_DICTIONARY_PATH, :abbreviations_collection => abbreviations_collection)

query = "directv royal oak mi"
@show SearchRequestProcessor.Abbreviations.extract_abbreviations(query)