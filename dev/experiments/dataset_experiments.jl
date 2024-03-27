using SearchRequestProcessor

doc_ids = SearchRequestProcessor.Evaluation.read_correct_document_ids()

exist_parts = map(doc_ids) do id
  replace(id, r"_\d+$" => "")
end

count_parts = Dict()

for part in exist_parts
  get!(count_parts, part, 0)

  count_parts[part] += 1
end

@show count_parts