using CSV
using MD5
using ProgressMeter
using WordTokenizers

const QUERIES_FILE_PATH = "dev/data/2023_queries.tsv"

function extract_existing_abbreviations(wikidata_abbreviations_dict::AbstractDict)::Vector{String}
  queries_full_text = CSV.File(QUERIES_FILE_PATH, header = [:ID, :QUERY]).QUERY |> queries -> join(queries, " ")

  wikidata_abbreviations =
    map(collect(values(wikidata_abbreviations_dict))) do defs
      map(def -> String(def[:source]), defs)
    end |> Iterators.flatten |> unique

  wiki_abbreviation_occurance_dict = Dict()

  @info "Calculate abbreviations occurance..."
  @showprogress for abbr in wikidata_abbreviations
    if !haskey(wiki_abbreviation_occurance_dict, abbr) && length(abbr) >= 2
      occurance = abbreviation_occurance(lowercase(abbr), queries_full_text)

      wiki_abbreviation_occurance_dict[abbr] = occurance
    end
  end

  existing_abbreviations =
    collect(wiki_abbreviation_occurance_dict) |>
    pairs -> filter(pair -> last(pair) > 0, pairs) |>
             pairs -> map(String ∘ uppercase ∘ first, pairs) |>
                      unique

  filter(existing_abbreviations) do abbr
    length(abbr) > 1 && length(abbr) <= 5 && !isnothing(match(r"\p{Latin}", abbr))
  end
end

function parse_existing_abbreviations(
  existing_abbreviations::Vector{String},
  finder_abbreviations::AbstractDict,
  wikidata_abbreviations::AbstractDict
)::CollectionDictionary
  existing_abbreviations_dict = Dict{Symbol, Vector{String}}()

  for abbreviation in existing_abbreviations
    sym_abbreviation = Symbol(abbreviation)

    existing_abbreviations_dict[sym_abbreviation] = []

    clean_definition = (def) -> replace(def, r"\(.+\)" => "") |> strip |> String

    if haskey(finder_abbreviations, abbreviation) && finder_abbreviations[abbreviation] !== false
      append!(
        existing_abbreviations_dict[sym_abbreviation],
        map(finder_abbreviations[abbreviation]) do def
          def["definition"]
        end .|> clean_definition
      )
    end

    if haskey(wikidata_abbreviations, abbreviation)
      append!(
        existing_abbreviations_dict[sym_abbreviation],
        map(wikidata_abbreviations[abbreviation]) do def
          def[:definition]
        end .|> clean_definition
      )
    end

    if isempty(existing_abbreviations_dict[sym_abbreviation])
      delete!(existing_abbreviations_dict, sym_abbreviation)
    else
      filter!(existing_abbreviations_dict[sym_abbreviation]) do definition
        lowercase(definition) != lowercase(abbreviation)
      end

      unique!(lowercase, existing_abbreviations_dict[sym_abbreviation])
    end
  end

  existing_abbreviations_dict
end

function abbreviation_occurance(abbreviation::AbstractString, full_text::AbstractString)::Integer
  regex =
    try
      # Escape special characters for regex
      replace(abbreviation, r"([()\[\]+*?|.])" => "\\\1") |>
      abbr -> "[. ,;?!]$abbr[. ,;?!]" |>
              Regex
    catch
      @info abbreviation
      return 0
    end

  eachmatch(regex, full_text) |> collect |> length
end
