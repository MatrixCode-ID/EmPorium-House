using Em.Ui.Core.Shared;
using Em.Ui.Wpf.Core;
using Em.Ui.Wpf.Shared;

namespace EmPoriumHouse.Home
{
   /// <summary>
   /// Pemasangan layar home EmPorium House sebagai pengganti home bawaan engine. Layar home hanya ada
   /// di layout satu halaman, jadi host memanggil <c>UseSinglePageLayout</c> dan <c>UseHomeNavigation</c>
   /// bersamaan.
   /// </summary>
   public static class EmPoriumHome
   {
      /// <summary>Nama navigasi home; engine memanggil kembali home lewat nama ini.</summary>
      public const string NavigationName = "Home";

      /// <summary>
      /// Memakai layout satu halaman dengan home EmPorium House. Navigasinya tidak masuk menu dan tidak
      /// bisa di-detach, sama seperti home bawaan.
      /// </summary>
      public static void UseEmPoriumHome(this EmAppBuilder builder) {
         ArgumentNullException.ThrowIfNull(builder);

         builder.UseSinglePageLayout();
         builder.UseHomeNavigation(new Navigation {
            Name = NavigationName,
            Title = "Home",
            Subtitle = "",
            Description = "",
            OrderIndex = -1,
            BodyType = BodyType.Of<EmPoriumHomeControl>(),
            Kind = NavigationKind.Manager,
            RequireParameter = false,
            IsMenuVisible = false,
            IsDetachVisible = false
         });
      }
   }
}
