using Em.Api.Core;

/*
   Configuration: copy emapi-config.example.json to ..\.artefacts\EmPorium\config\emapi-config.json beside the
   repository and fill in the database and initial admin password. The build copies it to the output; it is
   never published. EM_* environment variables override the file (see Helper.cs).

   Database prerequisites: the em-system scripts in doc/sqlscript/mssql: tables/010-core.sql, the registry
   (tables/030-registry.sql), NuPak (tables/040-nupak.sql) when the NuGet server is turned on, then views/.

   Features: the engine's standard features (users, roles, robots, business tasks) are always on. The others are
   switched in the config file, "modules": { "containerRegistry": true, "cdn": false, "nuget": false }, or with
   EM_MODULE_<NAME>=true|false. The desktop client follows the server: a module that is off has no card.
 */

var app = EmApp.BuildApp(args, builder => {
   var config = EmPoriumHouse.Api.Helper.ApplyConfig(builder);
   if (config.IsModuleEnabled(EmPoriumHouse.Api.Helper.ContainerRegistryModule, true)) {
      builder.AddContainerRegistry(config.Storage.RegistryPath);
   }

   if (config.IsModuleEnabled(EmPoriumHouse.Api.Helper.CdnModule)) {
      builder.EnableCdn(config.Storage.CdnPath, config.Storage.CdnMaxFileSizeMb);
   }

   if (config.IsModuleEnabled(EmPoriumHouse.Api.Helper.NuGetModule)) {
      builder.AddNuPak(config.Storage.NuPakPath, config.Storage.NuPakMaxPackageMb);
   }
});

app.Run();
