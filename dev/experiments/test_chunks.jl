using SearchRequestProcessor
using JSON3

transformer_adapter = SearchRequestProcessor.Chunks.TransformerEmbeddingsAdapter()
file_name = "dev/data/msmarco_v2_doc/msmarco_doc_00"

open(file_name) do io
  number_of_chunks = 0
  read_lines = 0

  while !eof(io)
    doc_data = readline(io) |> JSON3.read |> Dict

    document = SearchRequestProcessor.Chunks.Document(;
      id=doc_data[:docid],
      text=doc_data[:body]
    )

    chunks = SearchRequestProcessor.Chunks.get_document_chunks(transformer_adapter, [document])

    number_of_chunks += values(chunks) |> first |> keys |> length
    read_lines += 1

    @show [read_lines, number_of_chunks]
  end

  @show [read_lines, number_of_chunks]
end
