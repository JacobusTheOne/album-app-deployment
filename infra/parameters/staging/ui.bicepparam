using '../../ui.bicep'

// uiImageTag is read from the environment at compile time, so the deploying
// workflow needs no --parameters arguments beyond this file.
param location = 'brazilsouth'
param environmentType = 'staging'
param environmentName = 'cae-album-staging'
param acrName = 'ca7e04894508acr'
param pullIdentityName = 'id-album-ui-acrpull-staging'
param minReplicas = 1
param maxReplicas = 2
param uiImageTag = readEnvironmentVariable('UI_IMAGE_TAG')
