using OpenAI

# include("utils/openai_patch.jl")

using DebugDataWriter
using Mocking
using ..Chunks

openai_api_key() = get(ENV, "OPENAI_API_KEY", "")
# const model_id = "gpt-4"
const model_id = "gpt-3.5-turbo-0125"
# const model_id = "gpt-4-1106-preview"

struct ChatResponse
  chat_id::String
  content::String
  raw_context::Vector{Dict}
end

struct OpenAIChatAPI
    token::String
    model::String

    OpenAIChatAPI() = new(Chunks.get_openai_secret_key(), model_id)
    OpenAIChatAPI(token, model) = new(token, model)
end

Base.isvalid(api::OpenAIChatAPI) = !isempty(api.token) && !isempty(api.model)

const EMPTY_OPENAI_RESPONSE = ChatResponse("", "", [])

function do_chat(
    api::OpenAIChatAPI,
    message::AbstractString,
    system_prompts=String[];
    context=[],
    json_response=false
)::ChatResponse
    result = EMPTY_OPENAI_RESPONSE
    query_messages = []
    if !isempty(system_prompts)
        push!(
            query_messages,
            Dict("role" => "system", "content" => join(system_prompts, "\n"))
        )
    end
    query = Dict("role" => "user", "content" => message)

    response = @mock OpenAI.create_chat(
        api.token,
        api.model,
        vcat(query_messages, context, [query]);
        http_kwargs=(readtimeout=90, retry=true,)
    )

    # @debug_output get_debug_id("create_chat") "OpenAI" response

    response.status != 200 && return result

    if (v = get(response.response, "choices", nothing)) isa AbstractArray &&
       !isempty(v) &&
       (v = get(first(v), "message", nothing)) isa AbstractDict &&
       (content = get(v, "content", nothing)) isa AbstractString
        result = ChatResponse(
            get(response.response, :id, ""),
            json_response ? clear_chat_content(content) : content,
            vcat(context, [query, v])
        )
    end

    return result
end

function clear_chat_content(result::AbstractString)
    first_open_bracet_pos = findfirst(==('{'), result)
    last_close_bracet_pos = findlast(==('}'), result)

    (isnothing(first_open_bracet_pos) || isnothing(last_close_bracet_pos)) && return ""

    result[first_open_bracet_pos:last_close_bracet_pos]
end
