using HTTP
using JSON
using EzXML
using Mocking
using ProgressMeter
using Suppressor

const USER_AGENTS = [
  "Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36",
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.83 Safari/537.1",
  "Mozilla/5.0 (Linux; Android 9; SM-G965F Build/PPR1.180610.011; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/74.0.3729.157 Mobile Safari/537.36",
  "Mozilla/5.0 (Linux; Android 7.1; Mi A1 Build/N2G47H) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.83 Mobile Safari/537.36",
  "Mozilla/5.0 (iPhone; CPU iPhone OS 12_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1"
]

const FINDER_ABBREVIATIONS_FILE_PATH = "dev/data/finder_abbreviations.json"

function parse_acronyms_finder(existing_abbreviations::Vector{String})
  fetch_abbreviations_from_finder(map(uppercase, existing_abbreviations))
end

function fetch_abbreviations_from_finder(existing_abbreviations::Vector{String})
  abbreviations_dict = JSON.parsefile(FINDER_ABBREVIATIONS_FILE_PATH)
  parsed_abbreviations = map(uppercase, collect(keys(abbreviations_dict)))

  request_headers() = Dict("User-Agent" => rand(USER_AGENTS))

  @info "Fetching abbreviations from acronyms finder..."
  @showprogress for abbreviation in existing_abbreviations
    try
      in(abbreviation, parsed_abbreviations) && continue

      @info "Fetch $abbreviation definitions..."

      response_success = false
      html = nothing
      tries = 0

      while !response_success
        tries += 1

        tries > 10 && error("Error while fetch abbreviations from finder")

        response = @mock HTTP.get(acronym_finder_url(abbreviation); headers=request_headers())
        
        @suppress html = response.body |> String |> parsehtml
        body = findfirst("//body", html)
        if match(r"Forbidden: IP address rejected", nodecontent(body)) !== nothing
          @info "Forbidden, sleep..."
      
          sleep(10)
        else
          response_success = true
        end
      end

      definition_rows = findall("//table/tbody/tr", html)

      if length(definition_rows) > 0
        definition_rows = filter(row -> length(nodes(row)) == 3, definition_rows) |>
          rows -> rows[begin:min(length(rows), 25)]

        abbreviations_dict[abbreviation] = map(definition_rows) do definition_row
          info = nodes(definition_row)
          definition = info[begin + 1] |> nodecontent |> String

          Dict("definition" => definition)
        end
      else
        title = findfirst("//h2[@class='acronym__title']", html)

        if !isnothing(title)
          definition =  title |> nodecontent |> c -> split(c, "stands for ") |> last |> String

          abbreviations_dict[abbreviation] = [Dict("definition" => definition)]
        else
          abbreviations_dict[abbreviation] = false
        end
      end

      open(f -> write(f, JSON.json(abbreviations_dict, 2)), FINDER_ABBREVIATIONS_FILE_PATH, "w")
    catch e
      @error e

      abbreviations_dict[abbreviation]=false
    end
  end


  abbreviations_dict
end

acronym_finder_url(abbreviation) = "https://www.acronymfinder.com/$(abbreviation).html"
