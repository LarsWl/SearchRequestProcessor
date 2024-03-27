using ..Chunks
using JSON

using ElasticsearchClient
using ElasticsearchClient: Client as ElasticClient

function create_index(os_client::ElasticClient)
  if !ElasticsearchClient.Indices.exists(os_client, index = INDEX_NAME)
    settings = JSON.parsefile("var/configs/hnsw_index_settings.json")
    ElasticsearchClient.Indices.create(os_client, index = INDEX_NAME, body=settings)
  end
end
