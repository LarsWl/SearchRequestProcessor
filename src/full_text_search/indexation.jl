using ..Chunks
using JSON

using ElasticsearchClient
using ElasticsearchClient: Client as ElasticClient

function create_index(os_client::ElasticClient, index_name, config_name)
  if !ElasticsearchClient.Indices.exists(os_client, index = index_name)
    settings = JSON.parsefile("var/configs/$config_name")
    ElasticsearchClient.Indices.create(os_client, index = index_name, body=settings)
  end
end
