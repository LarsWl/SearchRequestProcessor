using ElasticsearchClient
using ElasticsearchClient: Client as ElasticClient
using JSON3

using ..Chunks
using ..HnswSearch
using ..HnswSearch: INDEX_NAME as HNSW_INDEX_NAME
using ..FullTextSearch
using ..FullTextSearch: INDEX_NAME as FULL_TEXT_INDEX_NAME

const DATASET_PARTS =
  range(0, 69) |> 
  collect .|> 
  string |> 
  ids -> map(id -> length(id) == 1 ? "0" * id : id, ids)


function prepare_hnsw_search_index(
  create_index_func::Function,
  embeddings_adapter::Chunks.AbstractEmbeddingsAdapter,
  index_name::AbstractString,
  chunk_size=0
)
  bulk_os_client = ElasticsearchClient.Client(verbose=0, deserializer=identity)
  bulk_os_client.verified = true
  check_os_client = ElasticsearchClient.Client(verbose=0)

  global indexed_documents = 0
  global treshhold = 1000
  global indexed_batches = 0
  mutex = ReentrantLock()

  @show Threads.nthreads()
  
  @info "Create index"
  create_index_func(check_os_client)

  Threads.@threads for part_number in DATASET_PARTS
    process_corpus_part(part_number) do batch
      documents = 
        map(build_document, batch) |>
        docs -> filter_existed_documents(check_os_client, index_name, docs, part_number)
  
      chunks =
        try
          Chunks.get_document_chunks(embeddings_adapter, documents, chunk_size)
        catch e
          @error "Part Number: $part_number", e

          Dict()
        end
      batch_for_index = AbstractDict[]

      for doc_chunks in values(chunks), doc_chunk in doc_chunks
          operation_name = :index
          operation_body = Dict(
              :_id => doc_chunk.id,
              :data => Dict(
                  :text => doc_chunk.text,
                  :metadata => doc_chunk.metadata,
                  :embedding => doc_chunk.embedding
              )
          )

          push!(batch_for_index, Dict(operation_name => operation_body))

          if length(batch_for_index) == 10
            index_batch(bulk_os_client, index_name, batch_for_index)
            lock(mutex) do
              global indexed_batches += 1

              if indexed_batches % 100 == 0
                @info "Commmon Progress. Indexed batches: $indexed_batches"
              end
            end

            empty!(batch_for_index)
          end
      end

      index_batch(bulk_os_client, index_name, batch_for_index)
      lock(mutex) do
        global indexed_batches += 1

        if indexed_batches % 100 == 0
          @info "Commmon Progress. Indexed batches: $indexed_batches"
        end
      end

      lock(mutex) do 
        global indexed_documents += length(batch)

        if indexed_documents >= treshhold
          treshhold += 2000
          ElasticsearchClient.Indices.refresh(check_os_client, index=index_name)

          @info "Commmon Progress. Indexed Documents: $indexed_documents"
        end
      end

      length(documents)
    end
  end
end

function prepare_full_text_index(index_name, config_name)
  bulk_os_client = ElasticsearchClient.Client(verbose=1, deserializer=identity)
  bulk_os_client.verified = true
  check_os_client = ElasticsearchClient.Client(verbose=0)

  global indexed_documents = 0
  global treshhold = 1000
  mutex = ReentrantLock()

  @show Threads.nthreads()
  
  @info "Create index"
  FullTextSearch.create_index(check_os_client, index_name, config_name)

  Threads.@threads for part_number in DATASET_PARTS
    process_corpus_part(part_number) do batch
      batch_for_index = AbstractDict[]

      for document in batch
          operation_name = :index
          operation_body = Dict(
              :_id => document[:pid],
              :data => Dict(:body => document[:passage])
          )

          push!(batch_for_index, Dict(operation_name => operation_body))

          if length(batch_for_index) == 200
            index_batch(bulk_os_client, index_name, batch_for_index)
            empty!(batch_for_index)
          end
      end

      index_batch(bulk_os_client, index_name, batch_for_index)

      lock(mutex) do 
        global indexed_documents += length(batch)

        if indexed_documents >= treshhold
          treshhold += 1000

          @show "Commmon Progress. Indexed Documents: $indexed_documents"
          ElasticsearchClient.Indices.refresh(check_os_client, index=index_name)
        end
      end

      length(batch)
    end
  end
end

function index_batch(os_client, index, batch)
  tries = 0
  delay = 3

  while tries <= 3
    tries += 1

    try
      if !isempty(batch)
        response = ElasticsearchClient.bulk(os_client, index=index, body=batch).body

        # if isa(response, AbstractDict) && response["errors"]
        #   errors =
        #     map(response["items"]) do item
        #       get(item["index"], "error", missing)
        #     end |> skipmissing |> collect |> errs -> join(errs, "\n")

        #   throw(ErrorException(errors))
        # end
      end
    catch e
      @error "Indexed IDS: $(map(d -> d[:index][:_id], batch))"
      @error string(e)
      sleep(delay)

      delay * 2
    end
  end
end

function filter_existed_documents(os_client, index_name, documents, part_number)
  query = Dict(
    :_source => [],
    :size => length(documents),
    :query => Dict(
      :ids => Dict(
        :values => map(doc -> doc.id * "_1", documents)
      )
    )
  )

  response =
    try
      ElasticsearchClient.search(os_client, index=index_name, body=query).body
    catch e
      @error e
      
      nothing
    end
  isnothing(response) && return documents

  existed_ids = map(hit -> hit["_id"], response["hits"]["hits"])

  if !isempty(existed_ids)
    # @info "Part Number: $part_number. Filtered IDs: $(length(existed_ids))"
    filter(doc -> !in("$(doc.id)_1", existed_ids), documents)
  else
    documents
  end  
end

function build_document(document_data::AbstractDict)::Chunks.Document
  Chunks.Document(;
    id=document_data[:pid],
    text=document_data[:passage]
  )
end

function build_document_title(document_data::AbstractDict)::Chunks.Document
  Chunks.Document(;
    id=document_data[:docid] * "_title",
    text=document_data[:title]
  )
end
