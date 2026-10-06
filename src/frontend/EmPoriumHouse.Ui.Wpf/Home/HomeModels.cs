using System.Collections.ObjectModel;
using System.Windows.Media;
using Em.Ui.Core.Shared;
using Em.Ui.Wpf.Shared;
using FontAwesome6;

namespace EmPoriumHouse.Home
{
   /// <summary>Keadaan satu modul di kartu home; menentukan warna titik status.</summary>
   public enum HomeStatus
   {
      /// <summary>Data kartu sedang dimuat dari server.</summary>
      Loading,

      /// <summary>Modul aktif dan bisa dibuka.</summary>
      Ready,

      /// <summary>Modul ada tetapi tidak bisa dipakai: tanpa hak akses atau server tidak menjawab.</summary>
      Warning,

      /// <summary>Server tidak menyalakan modul ini.</summary>
      Off,

      /// <summary>Modul belum ada; kartunya hanya penanda.</summary>
      Soon
   }

   /// <summary>Satu angka ringkas di kartu modul, mis. jumlah container.</summary>
   public sealed record HomeStat(string Value, string Label);

   /// <summary>Satu tile pintasan ke sebuah layar (administrasi atau menu module).</summary>
   public sealed class HomeTile
   {
      /// <summary>Judul tile.</summary>
      public required string Title { get; init; }

      /// <summary>Baris kedua tile; kosong berarti disembunyikan.</summary>
      public string SubTitle { get; init; } = string.Empty;

      /// <summary>Ikon tile, diambil dari navigasi asalnya.</summary>
      public required ImageSource Icon { get; init; }

      /// <summary>Perintah yang membuka layar tujuan.</summary>
      public required UiCommandBase Command { get; init; }
   }

   /// <summary>
   /// Kartu satu modul produk (container registry, CDN, NuGet) di home: nama, status, angka ringkas,
   /// alamat pakai, dan tombol ke layar pengelolanya.
   /// </summary>
   public class ModuleCardVm : MvvmModelBase
   {
      /// <summary>Nama modul.</summary>
      public string Title {
         get => Get("");
         set => Set(value);
      }

      /// <summary>Satu-dua kalimat tentang kegunaan modul.</summary>
      public string Description {
         get => Get("");
         set => Set(value);
      }

      /// <summary>Ikon modul.</summary>
      public EFontAwesomeIcon Icon {
         get => Get(EFontAwesomeIcon.Solid_Cube);
         set => Set(value);
      }

      /// <summary>Keadaan modul saat ini.</summary>
      public HomeStatus Status {
         get => Get(HomeStatus.Loading);
         set => Set(value);
      }

      /// <summary>Teks di samping titik status.</summary>
      public string StatusText {
         get => Get("");
         set => Set(value);
      }

      /// <summary>
      /// Alamat yang dipakai developer untuk modul ini (mis. host untuk <c>docker push</c>). Kosong
      /// berarti baris alamat disembunyikan.
      /// </summary>
      public string Endpoint {
         get => Get("");
         set => Set(value);
      }

      /// <summary>Label tombol utama kartu.</summary>
      public string ActionText {
         get => Get("");
         set => Set(value);
      }

      /// <summary>Perintah tombol utama, atau <c>null</c> kalau modul belum punya layar pengelola.</summary>
      public UiCommandBase? OpenCommand {
         get => Get<UiCommandBase?>();
         set => Set(value);
      }

      /// <summary>Perintah menyalin <see cref="Endpoint"/> ke clipboard.</summary>
      public UiCommandBase? CopyCommand {
         get => Get<UiCommandBase?>();
         set => Set(value);
      }

      /// <summary>Angka ringkas modul; kosong sampai datanya selesai dimuat.</summary>
      public ObservableCollection<HomeStat> Stats { get; } = [];

      /// <summary>Refresh seluruh informasi card dinamis; null untuk card statis.</summary>
      public UiCommandBase? RefreshCommand {
         get => Get<UiCommandBase?>();
         set => Set(value, _ => NotifyChanged(nameof(HasRefresh)));
      }

      public bool HasRefresh => RefreshCommand is not null;
      public UiCommandBase? ToggleCommand { get => Get<UiCommandBase?>(); set => Set(value, _ => NotifyChanged(nameof(HasToggle))); }
      public bool HasToggle => ToggleCommand is not null;
      public bool Enabled { get => Get<bool>(); set => Set(value); }
      public string ToggleTooltip { get => Get(""); set => Set(value); }


      public bool IsRefreshing {
         get => Get<bool>();
         set => Set(value, _ => { RefreshCommand?.RaiseCanExecuteChanged(); ToggleCommand?.RaiseCanExecuteChanged(); });
      }

      public string StorageCaption {
         get => Get("");
         set => Set(value);
      }

      public string StorageDescription { get; init; } = "";
   }
}
