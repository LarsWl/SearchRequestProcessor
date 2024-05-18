module Abbreviations

const CollectionDictionary = Dict{Symbol, Vector{String}}
const COLLECTION_DICTIONARY_PATH = "var/models/abbreviations_collection.jlso"

include("parsing/Parsing.jl")
include("scoring.jl")

using Memoize
using WordTokenizers

function extract_abbreviations(query::AbstractString)
  abbreviations = get_abbreviations_collection()

  results = CollectionDictionary()

  abbrs =
    map(Symbol ∘ uppercase, tokenize(query)) |>
    tokens -> filter(tok -> haskey(abbreviations, tok), tokens)
    
  isempty(abbrs) && return results

  abbr = last(abbrs)
  results[abbr] = abbreviations[abbr]

  return results
end

@memoize function get_abbreviations_collection()::CollectionDictionary
  JLSO.load(COLLECTION_DICTIONARY_PATH)[:abbreviations_collection]
end

end
