targetScope = 'resourceGroup'

@description('North Europe Logic App name.')
param northEuropeWorkflowName string = 'proxy-proof-region-1-la'

@description('West Europe Logic App name.')
param westEuropeWorkflowName string = 'proxy-proof-region-2-la'

@description('North Europe location.')
param northEuropeLocation string = 'northeurope'

@description('West Europe location.')
param westEuropeLocation string = 'westeurope'

@description('North Europe Container Apps proxy base URL.')
param northEuropeProxyUrl string

@description('West Europe Container Apps proxy base URL.')
param westEuropeProxyUrl string

var workflowSchema = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'

resource northEuropeWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: northEuropeWorkflowName
  location: northEuropeLocation
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': workflowSchema
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                runId: {
                  type: 'string'
                }
              }
            }
          }
        }
      }
      actions: {
        Call_North_Europe_Proxy: {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: '${northEuropeProxyUrl}/proxy/all'
          }
          runAfter: {}
        }
        Return_Proxy_Result: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            body: {
              enforcedPath: 'logic-app-to-north-europe-container-apps-proxy'
              proxyUrl: northEuropeProxyUrl
              proxyResult: '@body(\'Call_North_Europe_Proxy\')'
            }
          }
          runAfter: {
            Call_North_Europe_Proxy: [
              'Succeeded'
            ]
          }
        }
      }
      outputs: {}
    }
    parameters: {}
  }
}

resource westEuropeWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: westEuropeWorkflowName
  location: westEuropeLocation
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': workflowSchema
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                runId: {
                  type: 'string'
                }
              }
            }
          }
        }
      }
      actions: {
        Call_West_Europe_Proxy: {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: '${westEuropeProxyUrl}/proxy/all'
          }
          runAfter: {}
        }
        Return_Proxy_Result: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            body: {
              enforcedPath: 'logic-app-to-west-europe-container-apps-proxy'
              proxyUrl: westEuropeProxyUrl
              proxyResult: '@body(\'Call_West_Europe_Proxy\')'
            }
          }
          runAfter: {
            Call_West_Europe_Proxy: [
              'Succeeded'
            ]
          }
        }
      }
      outputs: {}
    }
    parameters: {}
  }
}

output northEuropeWorkflow string = northEuropeWorkflow.name
output westEuropeWorkflow string = westEuropeWorkflow.name