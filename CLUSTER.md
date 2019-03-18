# Fast setup of k8s cluster
> Make sure your envs are correct
```shell
export $(grep -v '^#' ./.secrets/.env | xargs -d '\n')
```
```shell
$ gcloud container clusters create "$K8S_CLUSTER" --zone "$K8S_ZONE" --num-nodes "$NUM_NODES"
$ gcloud container clusters get-credentials "$K8S_CLUSTER" --zone "$K8S_ZONE"
```

# Setup k8s cluster w/ `Deployment Manager`

**`Deployment Manager` can completely control a k8s cluster. It can also completely wack a cluster and everything on it. When a deployment fails, it will still wack the cluster if you delete the deployment. Be careful.**

```shell
$ mkdir deploy && mkdir deploy/templates
```

> Create `kubernetes_engine.py`

```
$ cat > $PWD/deploy/templates/kubernetes_engine.py <<- EOM
def GenerateConfig(context):
  """Generate YAML resource configuration."""

  cluster_name = context.properties['CLUSTER_NAME']
  cluster_zone = context.properties['CLUSTER_ZONE']
  number_of_nodes = context.properties['NUM_NODES']

  resources = []
  outputs = []
  resources.append({
      'name': cluster_name,
      'type': 'container.v1.cluster',
      'properties': {
          'zone': cluster_zone,
          'cluster': {
              'name': cluster_name,
              'initialNodeCount': number_of_nodes,
              'nodeConfig': {
                  'oauthScopes': [
                      'https://www.googleapis.com/auth/' + scope
                      for scope in [
                          'compute',
                          'devstorage.read_only',
                          'logging.write',
                          'monitoring'
                        ]
                    ]
                }
            }
        }
    })
  outputs.append({
        'name': 'endpoint',
        'value': '\$(ref.' + cluster_name + '.endpoint)'
    })
  return {'resources': resources, 'outputs': outputs}
EOM
```

> Create `kubernetes_engine_apis.py`
```shell
$ cat > $PWD/deploy/templates/kubernetes_engine_apis.py <<- EOM
def GenerateConfig(context):
  """Generate YAML resource configuration."""

  endpoints = {
      '-v1': 'api/v1',
      '-v1beta1-apps': 'apis/apps/v1beta1',
      '-v1beta1-extensions': 'apis/extensions/v1beta1'
  }

  resources = []
  outputs = []

  for type_suffix, endpoint in endpoints.iteritems():
    resources.append({
        'name': 'kubernetes' + type_suffix,
        'type': 'deploymentmanager.v2beta.typeProvider',
        'properties': {
            'options': {
                'validationOptions': {
                    'schemaValidation': 'IGNORE_WITH_WARNINGS'
                },
                'inputMappings': [{
                    'fieldName': 'name',
                    'location': 'PATH',
                    'methodMatch': '^(GET|DELETE|PUT)$',
                    'value': '$.ifNull('
                             '$.resource.properties.metadata.name, '
                             '$.resource.name)'
                }, {
                    'fieldName': 'metadata.name',
                    'location': 'BODY',
                    'methodMatch': '^(PUT|POST)$',
                    'value': '$.ifNull('
                             '$.resource.properties.metadata.name, '
                             '$.resource.name)'
                }, {
                    'fieldName': 'Authorization',
                    'location': 'HEADER',
                    'value': '$.concat("Bearer ",'
                             '$.googleOauth2AccessToken())'
                }]
            },
            'descriptorUrl':
                ''.join([
                    'https://' + context.properties['endpoint'] + '/swaggerapi/',
                    endpoint
                ])
        }
    })

  return {'resources': resources}
EOM
```

> Create `generate_apis.yaml`
```shell
$ cat > $PWD/deploy/generate_apis.yaml <<- EOM
imports:
- path: templates/kubernetes_engine.py
- path: templates/kubernetes_engine_apis.py

resources:
- name: cluster
  type: kubernetes_engine.py
  properties:
    CLUSTER_NAME: $K8S_CLUSTER
    CLUSTER_ZONE: $K8S_ZONE
    NUM_NODES: $k8S_NUM_NODES
- name: types
  type: kubernetes_engine_apis.py
  properties:
    endpoint: \$(ref.cluster.endpoint)
EOM
```

> Now simply run
```
$ gcloud deployment-manager deployments create ${APP_INSTANCE_NAME} \
--config=$PWD/deploy/generate_apis.yaml \
--project=$PROJECT_NAME
```