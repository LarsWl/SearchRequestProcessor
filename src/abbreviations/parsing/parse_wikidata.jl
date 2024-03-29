using HTTP
using JSON
using DebugDataWriter

const WIKIDATA_SPARQL_API = "https://query.wikidata.org/sparql?"
const WIKIDATA_ABBREVIATIONS_FILE_PATH = "dev/data/wikidata_abbreviations.jlso"

sparql_query =
    "query=" *
    HTTP.escapeuri("""
      SELECT DISTINCT ?item ?itemLabel ?shortname
      WHERE 
      {
        ?item wdt:P1813 ?shortname.
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        FILTER(langMatches(lang(?shortname), "MUL") || langMatches(lang(?shortname), "EN"))
        FILTER(regex(?shortname, '(^|[ ,;-]|)[0-9a-zA-Z]+[A-Z]+[0-9a-z]*(\$|[ ,;-]|)'))
      }
    """
    ) *
    "&" *
    "format=json"

function parse_wikidata_abbreviations()
  @info "Fetching wikidata abbreviations..."
  
  response = HTTP.get(WIKIDATA_SPARQL_API * sparql_query)

  @debug_output get_debug_id("wikidata") "Wikidata" String(response.body)

  wikidata_abbreviations_dict = Dict()
  abbreviations_data = String(response.body) |> JSON.parse

  for abbr_data in abbreviations_data["results"]["bindings"]
    abbr = abbr_data["shortname"]["value"] |> uppercase
    definition = abbr_data["itemLabel"]["value"] |> String
  
    get!(() -> [], wikidata_abbreviations_dict, abbr)
  
    push!(
      wikidata_abbreviations_dict[abbr],
      Dict(
        :source => abbr_data["shortname"]["value"],
        :definition => definition
      )
    )
  end

  JLSO.save(WIKIDATA_ABBREVIATIONS_FILE_PATH, :wikidata_abbreviations => wikidata_abbreviations_dict)
end
