using CSV
using JSON3

const DOCUMENTS_INDEX_NAME = "passages"

function process_corpus_part(index_func::Function, part_number)
  @info "Process part $part_number"

  passages_ids = read_correct_document_ids() |> sort

  file_name = "dev/data/msmarco_v2_passage/msmarco_passage_$(part_number)"

  indexed_docs =
    open(file_name) do io
      current_line = 0
      indexed_docs = 0
      batch = AbstractDict[]
      reading_incorrect = 0

      while !eof(io)
        current_line += 1
        if current_line % 250_000 == 0
          @info "Part: $part_number, readed lines: $current_line"
        end
    
        data = readline(io)
        doc = JSON3.read(data) |> Dict
    
        if insorted(doc[:pid], passages_ids)
          push!(batch, doc)
        elseif reading_incorrect < 5000
          push!(batch, doc)
          reading_incorrect += 1
        end

        if length(batch) == 100
          indexed_docs += index_func(batch)

          empty!(batch)
        end
      end

      indexed_docs += index_func(batch)

      indexed_docs
    end

  @info "Part: $part_number. Indexed documents: $indexed_docs"

  indexed_docs
end
