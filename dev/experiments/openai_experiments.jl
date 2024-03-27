using SearchRequestProcessor
using DebugDataWriter

# Enable adding trace info with the @info macro
# Each record contains links to the source code and to the saved data file 
DebugDataWriter.config().enable_log = true
DebugDataWriter.config().enable_dump = true

adapter = SearchRequestProcessor.Chunks.OpenAIEmbeddingsAdapter()

SearchRequestProcessor.Chunks.create_embeddings(adapter, "some important text")