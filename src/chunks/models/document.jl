# This file was generated by the Julia OpenAPI Code Generator
# Do not modify this file directly. Modify the OpenAPI specification instead.


@doc raw"""Document

    Document(;
        id=nothing,
        text=nothing,
        metadata=nothing,
    )

    - id::String
    - text::String
    - metadata::DocumentMetadata
"""
Base.@kwdef mutable struct Document
    id::Union{Nothing, String} = nothing
    text::Union{Nothing, String} = nothing
    metadata = nothing # spec type: Union{ Nothing, DocumentMetadata }
end # type Document
