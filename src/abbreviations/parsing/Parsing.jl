using JSON
using JLSO
using Memoize

# include("parse_search_terms.jl")
include("parse_acronyms_finder.jl")
include("parse_wikidata.jl")
include("parse_existing_abbreviations.jl")

function parse_new_abbreviations()::CollectionDictionary
  wikidata_abbreviations = JLSO.load(WIKIDATA_ABBREVIATIONS_FILE_PATH)[:wikidata_abbreviations]
  existing_abbreviations = extract_existing_abbreviations(wikidata_abbreviations)

  finder_abbreviations = parse_acronyms_finder(existing_abbreviations)

  # Save to output actual abbreviation dicts
  open(f -> write(f, JSON.json(finder_abbreviations)), FINDER_ABBREVIATIONS_FILE_PATH, "w")


  parse_existing_abbreviations(
    existing_abbreviations,
    finder_abbreviations,
    wikidata_abbreviations
  )
end
