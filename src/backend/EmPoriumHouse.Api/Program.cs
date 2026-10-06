using Em.Api.Core;

/*
   Configuration: copy emapi-config.example.json to ..\.artefacts\EmPorium\config\emapi-config.json beside the
   repository and fill in the database and initial admin password. The build copies it to the output; it is
   never published. EM_* environment variables override the file (see Helper.cs).

   Database prerequisites: the em-system core and registry scripts (doc/sqlscript/mssql/sets/Ctn.sql) and
   the em-system NuPak script (doc/sqlscript/mssql/sets/NuPak.sql).
 */

var app = EmApp.BuildApp(args, builder => {
   var config = EmPoriumHouse.Api.Helper.ApplyConfig(builder);
   builder.AddNuPak(config.Storage.NuPakPath, config.Storage.NuPakMaxPackageMb);
   builder.EnableCdn(config.Storage.CdnPath, config.Storage.CdnMaxFileSizeMb);
   builder.AddContainerRegistry(config.Storage.RegistryPath);
});

app.Run();
