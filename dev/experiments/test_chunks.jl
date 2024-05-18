using SearchRequestProcessor
using JSON3
using JSON

transformer_adapter = SearchRequestProcessor.Chunks.TransformerEmbeddingsAdapter()
file_name = "dev/data/msmarco_v2_passage/msmarco_passage_00"

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

lines = readlines(file_name)
doc_data = JSON3.read(lines[begin + 15])

document = SearchRequestProcessor.Chunks.Document(;
      id=doc_data[:pid],
      text=doc_data[:passage]
    )


chunks = SearchRequestProcessor.Chunks.get_document_chunks(adapter, [document])

chunks["msmarco_passage_00_5670"]