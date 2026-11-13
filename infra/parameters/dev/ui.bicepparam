using '../../ui.bicep'

// uiImageTag is read from the environment at compile time, so the deploying
// workflow needs no --parameters arguments beyond this file.
param location = 'brazilsouth'
param environmentType = 'development'
param environmentName = 'cae-album-private'
param acrName = 'ca7e04894508acr'
param pullIdentityName = 'id-album-ui-acrpull'
param minReplicas = 0
param maxReplicas = 1
param uiImageTag = readEnvironmentVariable('UI_IMAGE_TAG')
