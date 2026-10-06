using Em;
using Em.Api.Core.Models;
using System.Collections.ObjectModel;
using Em.Shared;
using Em.Ui.Core.Shared;
using Em.Ui.Wpf.Core;
using Em.Ui.Wpf.Shared;
using FontAwesome6;
using Microsoft.Extensions.DependencyInjection;
using UserControl = System.Windows.Controls.UserControl;

namespace EmPoriumHouse.Home
{
   /// <summary>
   /// Layar home EmPorium House: ringkasan modul yang dipasang server (container registry, CDN, NuGet
   /// yang direncanakan) berikut angka dan alamat pakainya, pintasan administrasi, dan menu module lain.
   /// Angka kartu dimuat ulang setiap pengguna kembali ke home.
   /// </summary>
   public partial class EmPoriumHomeControl : UserControl, INavigationBody
   {
      /// <summary>Membuat layar home untuk aplikasi <paramref name="app"/>.</summary>
      public EmPoriumHomeControl(EmApp app) {
         InitializeComponent();
         Vm.Attach(app);
      }

      /// <summary>ViewModel layar ini.</summary>
      public EmPoriumHomeVm Vm => (EmPoriumHomeVm)DataContext;

      private void ServerToggle_Click(object sender, System.Windows.RoutedEventArgs e) {
         // Restore the server value before the command runs: cancellation and failed requests
         // must not leave the switch showing a change the server has not accepted.
         var toggle = (System.Windows.Controls.Primitives.ToggleButton)sender;
         toggle.GetBindingExpression(System.Windows.Controls.Primitives.ToggleButton.IsCheckedProperty)?.UpdateTarget();
      }

      /// <inheritdoc />
      public Task OnNavigatingIn(INavigation sender, NavigatingEventArgs args) => Task.CompletedTask;

      /// <inheritdoc />
      public Task OnNavigatingAway(INavigation sender, NavigatingEventArgs args) => Task.CompletedTask;

      /// <inheritdoc />
      public Task OnReloadRequested(INavigation sender, NavigationEventArgs args) => Vm.LoadAsync();

      /// <inheritdoc />
      public Task OnRelease(INavigation sender) => Task.CompletedTask;
   }

   /// <summary>ViewModel layar home EmPorium House.</summary>
   public class EmPoriumHomeVm : MvvmModelBase
   {
      private const string RegistryNav = "admin.container";
      private const string CdnNav = "admin.cdn";
      private const string NuGetNav = "admin.nupak";

      // Administration shortcuts shown as tiles. The CDN and container screens are not listed here
      // because they already have a card of their own.
      private static readonly string[] AdminNavs = ["admin.users", "admin.roles", "admin.tasks", "admin.release"];

      private EmApp? _app;

      /// <summary>Container registry.</summary>
      public ModuleCardVm Registry { get; } = new() {
         Title = "Container Registry",
         Description = "Push and pull container images over the OCI protocol, with robot accounts for CI.",
         Icon = EFontAwesomeIcon.Solid_Cubes,
         ActionText = "Open Container Manager",
         StorageDescription = "Unique stored blobs plus manifests, including retained blobs. Excludes temporary uploads and database/filesystem overhead. Based on registry metadata."
      };

      /// <summary>CDN.</summary>
      public ModuleCardVm Cdn { get; } = new() {
         Title = "CDN",
         Description = "Publish static files and downloads under a public path, served straight from your server.",
         Icon = EFontAwesomeIcon.Solid_CloudArrowUp,
         ActionText = "Open CDN Manager",
         StorageDescription = "Public file sizes across all CDN folders. Excludes internal/temporary, hidden/system files, symlinks and filesystem overhead."
      };

      /// <summary>NuGet server; belum ada, kartunya hanya penanda.</summary>
      public ModuleCardVm NuGet { get; } = new() {
         Title = "NuGet Server",
         Description = "Host and restore your own .NET packages without leaving your network.",
         Icon = EFontAwesomeIcon.Solid_Box,
         Status = HomeStatus.Loading,
         StatusText = "Checking...",
         ActionText = "Open NuGet Manager",
         StorageDescription = "Total includes active and recycled versions. Excludes temporary uploads and database/filesystem overhead."
      };

      /// <summary>Kartu modul dalam urutan tampil.</summary>
      public ObservableCollection<ModuleCardVm> Modules { get; } = [];

      /// <summary>Pintasan layar administrasi yang boleh dibuka pengguna.</summary>
      public ObservableCollection<HomeTile> AdminTiles { get; } = [];

      /// <summary>Menu module lain yang terpasang di aplikasi dan boleh dibuka pengguna.</summary>
      public ObservableCollection<HomeTile> AppTiles { get; } = [];

      /// <summary>Nama produk di header.</summary>
      public string TitleText {
         get => Get("");
         private set => Set(value);
      }

      /// <summary>Subtitle produk.</summary>
      public string TaglineText {
         get => Get("");
         private set => Set(value);
      }

      /// <summary>Slogan produk.</summary>
      public string SloganText {
         get => Get("");
         private set => Set(value);
      }

      /// <summary>Hak cipta di kaki halaman.</summary>
      public string CopyrightText {
         get => Get("");
         private set => Set(value);
      }

      /// <summary>Akun yang sedang masuk.</summary>
      public string UserText {
         get => Get("");
         private set => Set(value);
      }

      /// <summary>Server yang sedang dipakai.</summary>
      public string ServerText {
         get => Get("");
         private set => Set(value);
      }

      /// <summary>
      /// Menyambungkan ViewModel ke aplikasi dan menyusun semua yang tidak butuh server: teks branding,
      /// pintasan, dan perintah kartu. Angka kartu baru dimuat oleh <see cref="LoadAsync"/>.
      /// </summary>
      public void Attach(EmApp app) {
         _app = app;

         TitleText = app.Branding.DisplayTitle;
         TaglineText = app.Branding.DisplayTagline;
         SloganText = app.Branding.DisplayDescription;
         CopyrightText = app.Branding.DisplayCopyright;
         UserText = app.ActiveUser?.cUserAccount is { Length: > 0 } account ? account : "Debug session";
         ServerText = app.ActiveConnection?.Host is { Length: > 0 } host ? host : "No server selected";

         Modules.Clear();
         Modules.Add(Registry);
         Modules.Add(Cdn);
         Modules.Add(NuGet);

         BindCard(Registry, RegistryNav);
         BindCard(Cdn, CdnNav);
         BindCard(NuGet, NuGetNav);
         NuGet.ToggleTooltip = "Requires NuGet Settings Manage. Applies immediately.";
         NuGet.ToggleCommand = new UiCommandAsync("nupak.toggle", _ => ToggleNuGetAsync(), _ => CanManageNuGet && !NuGet.IsRefreshing && NuGet.Status is HomeStatus.Ready or HomeStatus.Off);
         BuildTiles();
      }

      /// <summary>
      /// Memuat angka kartu dari server. Setiap kartu gagal sendiri-sendiri: modul yang tidak dinyalakan
      /// atau tanpa hak akses hanya mengubah status kartunya, bukan menggagalkan halaman.
      /// </summary>
      public async Task LoadAsync() {
         if (_app is null) return;

         BuildTiles();
         await Task.WhenAll(LoadRegistryAsync(), LoadCdnAsync(), LoadNuGetAsync());
      }

      #region Cards

      // The open button is wired up front; whether the user may use it is decided here and again when
      // the numbers arrive, because a server that does not run the module answers 404 only then.
      private void BindCard(ModuleCardVm card, string navName) {
         var nav = FindNav(navName);
         var allowed = nav is not null && _app!.CanOpen(nav);
         card.OpenCommand = new UiCommandAsync($"{navName}.open", _ => _app!.NavigateTo(navName), _ => allowed);
         card.CopyCommand = new UiCommand($"{navName}.copy", _ => CopyToClipboard(card.Endpoint));
         card.RefreshCommand = new UiCommandAsync($"{navName}.refresh",
            _ => navName == RegistryNav ? LoadRegistryAsync() : navName == NuGetNav ? LoadNuGetAsync() : LoadCdnAsync(),
            _ => !card.IsRefreshing && IsAllowed(navName));

         card.Stats.Clear();
         if (allowed) {
            card.Status = HomeStatus.Loading;
            card.StatusText = "Checking...";
         }
         else {
            card.Status = HomeStatus.Warning;
            card.StatusText = "No access";
         }
      }

      private async Task LoadRegistryAsync() {
         if (!IsAllowed(RegistryNav) || Registry.IsRefreshing) return;

         var card = Registry;
         BeginRefresh(card);
         try {
            var service = _app!.ServiceProvider.GetRequiredService<ICtnServices>();
            var roots = await service.GetMeta_CtnRoots();

            card.Stats.Clear();
            card.Stats.Add(new HomeStat(roots.Length.ToString("N0"), "Roots"));
            card.Stats.Add(new HomeStat(roots.Sum(r => r.ImageCount).ToString("N0"), "Containers"));
            card.Endpoint = $"docker pull {RegistryHost()}/<root>/<name>";
            card.Status = HomeStatus.Ready;
            card.StatusText = "Running";
            await ReadStorageAsync(card, async () => {
               var storage = await service.GetMeta_CtnStorageSize();
               return $"Total image storage: {FormatSize(storage.TotalBytes)}";
            });
         }
         catch (Exception x) {
            ShowFailure(card, x);
         }
         finally { card.IsRefreshing = false; }
      }

      private async Task LoadCdnAsync() {
         if (!IsAllowed(CdnNav) || Cdn.IsRefreshing) return;

         var card = Cdn;
         BeginRefresh(card);
         try {
            var service = _app!.ServiceProvider.GetRequiredService<ICdnServices>();
            var root = await service.GetMeta_CdnFolder(null);

            card.Stats.Clear();
            card.Stats.Add(new HomeStat(root.Entries.Count(e => e.IsFolder).ToString("N0"), "Folders"));
            card.Stats.Add(new HomeStat(root.Entries.Count(e => !e.IsFolder).ToString("N0"), "Files"));
            if (root.MaxFileSize > 0) card.Stats.Add(new HomeStat(FormatSize(root.MaxFileSize), "Max upload"));
            card.Endpoint = $"{ServerBase()}/{(root.PublicPath.Length > 0 ? root.PublicPath.Trim('/') : "cdn")}/";
            card.Status = HomeStatus.Ready;
            card.StatusText = "Running";
            await ReadStorageAsync(card, async () => {
               var storage = await service.GetMeta_CdnStorageSize();
               return $"Total CDN storage: {FormatSize(storage.TotalBytes)} · {storage.FileCount:N0} files";
            });
         }
         catch (Exception x) {
            ShowFailure(card, x);
         }
         finally { card.IsRefreshing = false; }
      }

      private bool CanManageNuGet => _app is not null && _app.AllClaims.Any(c => c.ModuleName == Defaults.AdministrativeToolsModuleName && c.Name == INuPakServices.SettingsClaim)
         && new ClaimCollection(Defaults.AdministrativeToolsModuleName, _app.AllClaims, _app.ActiveUser)[INuPakServices.SettingsClaim];

      private async Task LoadNuGetAsync() {
         if (!IsAllowed(NuGetNav) || NuGet.IsRefreshing) return;
         var card = NuGet; BeginRefresh(card);
         try {
            var service = _app!.ServiceProvider.GetRequiredService<INuPakServices>();
            var status = await service.GetMeta_NuPakStatus();
            card.Enabled = status.Enabled;
            card.Status = status.Enabled ? HomeStatus.Ready : HomeStatus.Off;
            card.StatusText = status.Enabled ? "Ready" : "Off";
            card.Endpoint = "";
            card.Stats.Clear();
            card.Stats.Add(new(status.Feeds.ToString("N0"), "Feeds"));
            card.Stats.Add(new(status.EffectiveFeeds.ToString("N0"), "Active feeds"));
            card.Stats.Add(new(status.Packages.ToString("N0"), "Packages"));
            card.Stats.Add(new(status.Versions.ToString("N0"), "Versions"));
            await ReadStorageAsync(card, async () => {
               var size = await service.GetMeta_NuPakStorageSize();
               return $"Total package storage: {FormatSize(size.TotalBytes)} (includes recycle bin)";
            });
         } catch (Exception ex) { ShowFailure(card, ex); }
         finally { card.IsRefreshing = false; }
      }
      private async Task ToggleNuGetAsync() {
         if (!CanManageNuGet || NuGet.IsRefreshing) return;
         if (NuGet.Enabled && System.Windows.MessageBox.Show("Switch off the NuGet server? Clients will receive 404 until enabled again.", "NuGet Server",
            System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning) != System.Windows.MessageBoxResult.Yes) return;
         NuGet.IsRefreshing = true;
         try {
            var result = await _app!.ServiceProvider.GetRequiredService<INuPakServices>().PostGetMeta_NuPakSetEnabled(!NuGet.Enabled);
            NuGet.Enabled = result.Enabled; NuGet.Status = result.Enabled ? HomeStatus.Ready : HomeStatus.Off;
            NuGet.StatusText = result.Enabled ? "Ready" : "Off";
         } catch (Exception ex) { System.Windows.MessageBox.Show(ex.Message, "NuGet Server"); }
         finally { NuGet.IsRefreshing = false; }
         await LoadNuGetAsync();
      }

      private static void BeginRefresh(ModuleCardVm card) {
         card.IsRefreshing = true;
         card.Status = HomeStatus.Loading;
         card.StatusText = "Checking...";
         card.StorageCaption = "Storage: checking...";
      }

      // A server running an older engine may not publish the storage action yet. That does not
      // mean its entire module is off; keep the other card information and show storage unavailable.
      private static async Task ReadStorageAsync(ModuleCardVm card, Func<Task<string>> read) {
         try { card.StorageCaption = await read(); }
         catch (Exception) { card.StorageCaption = "Storage: unavailable"; }
      }

      // 404 is the server's way of saying the module is switched off; 401 and 403 mean the account
      // lacks the claim. Anything else is shown as unavailable rather than raised as an error dialog,
      // since the home screen must stay usable while one module is down.
      private static void ShowFailure(ModuleCardVm card, Exception x) {
         card.Stats.Clear();
         card.Endpoint = "";
         card.StorageCaption = "Storage: unavailable";
         (card.Status, card.StatusText) = x switch {
            ActionException { StatusCode: 404 } => (HomeStatus.Off, "Not enabled on this server"),
            ActionException { StatusCode: 401 or 403 } => (HomeStatus.Warning, "No access"),
            _ => (HomeStatus.Warning, "Unavailable")
         };
      }

      private bool IsAllowed(string navName) {
         var nav = FindNav(navName);
         return nav is not null && _app!.CanOpen(nav);
      }

      // "https://host:7260/" -> "https://host:7260"
      private string ServerBase() => (_app!.ActiveConnection?.Host ?? "").TrimEnd('/');

      // A registry address has no scheme: "https://host:7260" -> "host:7260".
      private string RegistryHost() {
         var host = ServerBase();
         var scheme = host.IndexOf("://", StringComparison.Ordinal);
         return scheme >= 0 ? host[(scheme + 3)..] : host;
      }

      private static string FormatSize(long bytes) => bytes switch {
         >= 1L << 30 => $"{bytes / (double)(1L << 30):0.#} GB",
         >= 1L << 20 => $"{bytes / (double)(1L << 20):0.#} MB",
         >= 1L << 10 => $"{bytes / (double)(1L << 10):0.#} KB",
         _ => $"{bytes} B"
      };

      private static void CopyToClipboard(string text) {
         if (string.IsNullOrWhiteSpace(text)) return;

         try {
            System.Windows.Clipboard.SetText(text);
         }
         catch (System.Runtime.InteropServices.COMException) {
            // Another process holds the clipboard; copying is a convenience, so there is nothing to report.
         }
      }

      #endregion

      #region Tiles

      private Navigation? FindNav(string name) => _app?.Navigations.FirstOrDefault(r => r.Name == name);

      // Rebuilt on every reload so a role change made elsewhere shows up when the user comes back.
      private void BuildTiles() {
         AdminTiles.Clear();
         foreach (var name in AdminNavs) {
            var nav = FindNav(name);
            if (nav is not null && _app!.CanOpen(nav)) AdminTiles.Add(ToTile(nav));
         }

         AppTiles.Clear();
         var menus = _app!.Navigations
            .Where(r => r.IsMenuVisible && r.Name != EmPoriumHome.NavigationName && _app.CanOpen(r))
            .OrderBy(r => r.OrderIndex)
            .ThenBy(r => r.Title);
         foreach (var nav in menus) AppTiles.Add(ToTile(nav));
      }

      private HomeTile ToTile(Navigation nav) => new() {
         Title = nav.Title,
         SubTitle = nav.Subtitle,
         Icon = nav.NavigationIcon,
         Command = new UiCommandAsync($"{nav.Name}.open", _ => _app!.NavigateTo(nav), _ => true)
      };

      #endregion
   }
}
