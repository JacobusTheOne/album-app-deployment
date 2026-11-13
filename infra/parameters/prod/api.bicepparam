using '../../api.bicep'

// apiImageTag and databaseUrl are read from the environment at compile time,
// so the deploying workflow needs no --parameters arguments beyond this file.
// Both are required: an unset variable fails the build instead of deploying
// a stale image or an empty connection string.
param location = 'brazilsouth'
param environmentType = 'production'
param environmentName = 'cae-album-prod'
param acrName = 'ca7e04894508acr'
param pullIdentityName = 'id-album-api-acrpull-prod'
param minReplicas = 1
param maxReplicas = 3
param apiImageTag = readEnvironmentVariable('API_IMAGE_TAG')
param databaseUrl = readEnvironmentVariable('DATABASE_URL')
