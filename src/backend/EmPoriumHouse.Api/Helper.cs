using Em.Api.Shared;

namespace EmPoriumHouse.Api;

/// <summary>
/// Reads the host's <see cref="EmApiConfig"/> from the local artefacts folder and applies it to the builder.
/// </summary>
internal static class Helper
{
   /// <summary>Environment variable holding an explicit path to emapi-config.json, e.g. a file mounted into a container.</summary>
   public const string ConfigPathVariable = "EM_API_CONFIG";

   /// <summary>
   /// Loads emapi-config.json from <c>EM_API_CONFIG</c>, or from the build output where the build copies
   /// <c>$(ArtefactsPath)config\emapi-config.json</c>. Returns false when neither file exists.
   /// </summary>
   public static bool TryLoadConfigArtefact(out EmApiConfig config) {
      var path = Environment.GetEnvironmentVariable(ConfigPathVariable);
      if (string.IsNullOrWhiteSpace(path)) {
         path = Path.Combine(AppContext.BaseDirectory, EmApiConfig.FileName);
      } else if (!File.Exists(path)) {
         throw new InvalidOperationException($"{ConfigPathVariable} points to '{path}', which does not exist.");
      }

      config = File.Exists(path) ? EmApiConfig.Load(path) : new EmApiConfig();
      return File.Exists(path);
   }

   /// <summary>
   /// Loads the artefact config, lets the EM_* environment variables override it (containers and secret
   /// managers supply those), then applies the result to <paramref name="builder"/>.
   /// </summary>
   public static EmApiConfig ApplyConfig(EmAppBuilder builder) {
      TryLoadConfigArtefact(out var config);
      ApplyEnvironment(config);

      try {
         builder.ApplyConfig(config);
      } catch (InvalidOperationException ex) {
         throw new InvalidOperationException(
            $"{ex.Message} Put it in ..\\.artefacts\\EmPorium\\config\\{EmApiConfig.FileName} beside the repository " +
            $"(see src/backend/EmPoriumHouse.Api/emapi-config.example.json), point {ConfigPathVariable} to the file, " +
            "or set the EM_* environment variables.", ex);
      }

      return config;
   }

   private static void ApplyEnvironment(EmApiConfig config) {
      if (Read("EM_DB_CONNECTION_STRING") is { } connectionString) {
         config.Database.ConnectionString = connectionString;
      }

      if (Read("EM_DB_PROVIDER") is { } providerName) {
         if (!Enum.TryParse<DatabaseProvider>(providerName, true, out var provider) || !Enum.IsDefined(provider)) {
            throw new InvalidOperationException("EM_DB_PROVIDER must be MicrosoftSqlServer, MySql, or PostgreSql.");
         }

         config.Database.Provider = provider;
      }

      if (Read("EM_ADMIN_INITIAL_PASSWORD") is { } password) {
         config.Admin.InitialPassword = password;
      }

      if (Read("EM_DEBUG_TOKEN") is { } publicKey) {
         var token = new EmApiConfig.DebugTokenSection { PublicKey = publicKey };
         config.DebugTokens.RemoveAll(t => string.Equals(t.Name, token.Name, StringComparison.OrdinalIgnoreCase));
         config.DebugTokens.Add(token);
      }
   }

   private static string? Read(string name) =>
      Environment.GetEnvironmentVariable(name) is { } value && !string.IsNullOrWhiteSpace(value) ? value : null;
}
