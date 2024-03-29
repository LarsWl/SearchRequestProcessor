
using CSV
using Suppressor

const SEARCH_TERMS_FILE_NAME = "search_terms.csv"
const STORWORDS_REGEX = [
  "excel", "word", "share", "safe", "power", "stress", "ted", "lead", "cyber", "sale", "data", "chan", "ruby", "c++", "java", "sql",
  "python", "script", "stress", "manag", "goal", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "sigma",
  "agile", "drive", "trust", "azure", "html", "web", "dev", "law", "lean", "hir", "desig", "bing", "google", "spread", "men",
  "risk", "legal", "emai", "dot", "food", "bias", "visi", "budg", "pump", "water", "hybr", "mail", "vide", "eu", "us", "es", "adobe",
  "table", "legal", "change", "japan", "http", "art", "team", "proje",
] |> w -> join(w, "|") |> stopwords_str -> Regex(stopwords_str, "i")

function extract_abbreviations_from_terms(input_dir::AbstractString)::Vector{String}
  search_terms_csv = @suppress CSV.File(joinpath(input_dir, SEARCH_TERMS_FILE_NAME), delim="|", escapechar='\\')

  filter(search_terms_csv) do term_row
    try
      kw = term_row[:KEYWORD]
      
      length(split(kw)) == 1 &&
        length(kw) > 1 &&
        !isnothing(match(r"\p{Latin}", kw)) &&
        match(STORWORDS_REGEX, kw) === nothing &&
        match(r"[()\\.,:]", kw) === nothing
    catch
      false
    end
  end |>
    term_rows -> map(term_row -> term_row[:KEYWORD], term_rows) .|>
    uppercase ∘ String
end
