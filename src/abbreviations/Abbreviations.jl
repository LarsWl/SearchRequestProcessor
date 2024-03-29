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

  foreach(tokenize(query)) do token
    abbr = Symbol(uppercase(token))
    definitions = get(abbreviations, abbr, nothing)

    if !isnothing(definitions)
      results[abbr] = definitions
    end
  end

  return results
end

@memoize function get_abbreviations_collection()::CollectionDictionary
  JLSO.load(COLLECTION_DICTIONARY_PATH)[:abbreviations_collection]
end

end
