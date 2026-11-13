using '../../api.bicep'

// apiImageTag and databaseUrl are read from the environment at compile time,
// so the deploying workflow needs no --parameters arguments beyond this file.
// Both are required: an unset variable fails the build instead of deploying
// a stale image or an empty connection string.
param location = 'brazilsouth'
param environmentType = 'staging'
param environmentName = 'cae-album-staging'
param acrName = 'ca7e04894508acr'
param pullIdentityName = 'id-album-api-acrpull-staging'
param minReplicas = 1
param maxReplicas = 2
param apiImageTag = readEnvironmentVariable('API_IMAGE_TAG')
param databaseUrl = readEnvironmentVariable('DATABASE_URL')
