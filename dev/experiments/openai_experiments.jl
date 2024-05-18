using SearchRequestProcessor
using DebugDataWriter

# Enable adding trace info with the @info macro
# Each record contains links to the source code and to the saved data file 
DebugDataWriter.config().enable_log = false
DebugDataWriter.config().enable_dump = false

adapter = SearchRequestProcessor.Chunks.OpenAIEmbeddingsAdapter()

SearchRequestProcessor.Chunks.calculate_embeddings(adapter, "some important text")

using ElasticsearchClient

client = ElasticsearchClient.Client()

ElasticsearchClient.Indices.refresh(client)