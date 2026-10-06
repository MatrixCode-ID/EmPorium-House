using EmPoriumHouse.Home;
using Em.Ui.Core.Shared;
using Em.Ui.Wpf.Core;
using Em.Ui.Wpf.Shared;

namespace EmPoriumHouse;

internal static class Program
{
   [STAThread]
   public static void Main(string[] args) {
      var emApp = EmApp.BuildApp(args, builder => {
         builder.ApplicationName = "EmPorium House";
         // No LogoSource yet: the core logo is used until EmPorium House has its own artwork.
         builder.ApplyBranding(new BrandingInfo {
            Title = "EmPorium House",
            Tagline = "Developer infrastructure platform",
            Description = "Self-hosted. Fully stocked.",
            Copyright = "© 2026 Matrix Code. All rights reserved."
         });
         builder.EnableAnimation = true;
         builder.UsePasswordPolicy(opt => {
            opt.MinLength = 8;
            opt.SymbolRule = PasswordRuleLevel.Off;
         });
#if DEBUG
         builder.AddDebug(opt => {
            opt.AddDebugConnection("Localhost", "http://localhost:5232", true, 180);
            if (ReadDevelopmentToken() is { } privateKey) {
               opt.SetDebugKey("Development Token", privateKey);
            }
         });
#endif

         // Single-page layout with EmPorium House's own home screen (see Home/).
         builder.UseEmPoriumHome();
         builder.EnableAnimation = true;
      });
      emApp.Run();
   }

#if DEBUG
   /// <summary>Private key embedded from ArtefactsPath at build time, or null when the file was not present.</summary>
   private static string? ReadDevelopmentToken() {
      using var stream = typeof(Program).Assembly.GetManifestResourceStream("DevelopmentToken");
      if (stream is null) return null;
      using var reader = new System.IO.StreamReader(stream);
      return reader.ReadToEnd().Trim();
   }
#endif
}
