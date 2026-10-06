using Em.Api.Core.Models;
using Em.Ui.Wpf.Navigations;
// Offline WPF render and refresh verification. Run with --artifacts-path if the host is open.
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Automation;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Em.Ui.Core.Shared;
using Em.Ui.Wpf.Core;
using Em.Ui.Wpf.Shared;
using EmPoriumHouse.Home;
using Microsoft.Extensions.DependencyInjection;

class Program {
 [STAThread] static void Main() {
  var application = new Application {ShutdownMode=ShutdownMode.OnExplicitShutdown};
  var app = (EmApp)Activator.CreateInstance(typeof(EmApp), BindingFlags.Instance | BindingFlags.NonPublic, null, [Array.Empty<string>()], null)!;
  typeof(EmApp).GetProperty("Branding")!.SetValue(app, new BrandingInfo());
  typeof(EmApp).GetProperty("IsDebugMode")!.SetValue(app, true);
  typeof(EmApp).GetField("_allClaims",BindingFlags.Instance|BindingFlags.NonPublic)!.SetValue(app, new[]{Em.Shared.ClaimAction.Create<Em.Api.Core.NuPakService>(INuPakServices.SettingsClaim)});
  var navs = (ICollection<Navigation>)app.Navigations;
  navs.Add(new Navigation { Name="admin.container", BodyType=BodyType.Of<EmPoriumHomeControl>(),Kind=NavigationKind.Manager,OrderIndex=0,RequireParameter=false });
  navs.Add(new Navigation { Name="admin.cdn", BodyType=BodyType.Of<EmPoriumHomeControl>(),Kind=NavigationKind.Manager,OrderIndex=0,RequireParameter=false });
  navs.Add(new Navigation { Name="admin.nupak", BodyType=BodyType.Of<NuPakManager>(),Kind=NavigationKind.Manager,OrderIndex=0,RequireParameter=false });
  var nuget = DispatchProxy.Create<INuPakServices, FakeService>();
  var np = (FakeService)(object)nuget;
  var registry = DispatchProxy.Create<ICtnServices, FakeService>();
  var cdn = DispatchProxy.Create<ICdnServices, FakeService>();
  var rp=(FakeService)(object)registry; var cp=(FakeService)(object)cdn;
  using var services = new ServiceCollection().AddSingleton(registry).AddSingleton(cdn).AddSingleton(nuget).BuildServiceProvider();
  typeof(EmApp).GetField("_serviceProvider", BindingFlags.Instance|BindingFlags.NonPublic)!.SetValue(app,services);
  var view = new EmPoriumHomeControl(app) { Width=1100, Height=900 };
  view.Vm.LoadAsync().GetAwaiter().GetResult();
  var root = new Border { Child=view,Width=1100,Height=900 };
  var apply=typeof(EmApp).Assembly.GetType("Em.Ui.Wpf.Shared.ThemeResources")!.GetMethod("Apply")!;
  foreach(var dark in new[]{false,true}) {
   apply.Invoke(null,[application.Resources,dark?(ThemeBase)new DarkTheme():new LightTheme()]);
   root.Background=(Brush)application.Resources["themeWindowBackgroundBrush"];
   view.Foreground=(Brush)application.Resources["themeWindowForegroundBrush"];
   Layout(root);
   Layout(root);
   var buttons=Descendants<Button>(root).Where(b=>AutomationProperties.GetName(b)=="Refresh module card" && b.Visibility==Visibility.Visible).ToArray();
   if(buttons.Length!=3)throw new Exception("Expected three visible refresh buttons");
   var registryButton=buttons.Single(b=>ReferenceEquals(b.DataContext,view.Vm.Registry));
   var cdnButton=buttons.Single(b=>ReferenceEquals(b.DataContext,view.Vm.Cdn));
   var beforeCdn=cp.Calls;
   rp.Pending=new TaskCompletionSource<CtnRootInfo[]>();
   var request=((UiCommandAsync)view.Vm.Registry.RefreshCommand!).ExecuteAsync(null);
   Layout(root);
   if(registryButton.IsEnabled || !cdnButton.IsEnabled || !view.Vm.Registry.IsRefreshing)throw new Exception("Card independence/disabled failed");
   var beforeRepeat=rp.Calls;
   ((UiCommandAsync)view.Vm.Registry.RefreshCommand!).ExecuteAsync(null).GetAwaiter().GetResult();
   if(rp.Calls!=beforeRepeat)throw new Exception("Duplicate request");
   Save(root,$"{(dark?"dark":"light")}-busy.png");
   rp.Pending.SetResult([new CtnRootInfo{ImageCount=7}]);rp.Pending=null;
   Pump(request);Layout(root);
   if(cp.Calls!=beforeCdn||!registryButton.IsEnabled||view.Vm.Registry.Stats[1].Value!="7")throw new Exception("Refresh failed");
   if(!view.Vm.Registry.StorageCaption.Contains("MB")||!view.Vm.Cdn.StorageCaption.Contains("files"))throw new Exception("Storage captions missing");
   Save(root,$"{(dark?"dark":"light")}-ready.png");
   rp.Fail=true;Pump(((UiCommandAsync)view.Vm.Registry.RefreshCommand!).ExecuteAsync(null));Layout(root);
   if(!registryButton.IsEnabled||view.Vm.Registry.Status!=HomeStatus.Warning)throw new Exception("Retry unavailable");
   rp.Fail=false;Pump(((UiCommandAsync)view.Vm.Registry.RefreshCommand!).ExecuteAsync(null));
   var beforeRegistry=rp.Calls;
   cp.CdnPending=new TaskCompletionSource<CdnFolderContent>();
   var cdnRequest=((UiCommandAsync)view.Vm.Cdn.RefreshCommand!).ExecuteAsync(null);Layout(root);
   if(cdnButton.IsEnabled||!registryButton.IsEnabled)throw new Exception("CDN busy isolation failed");
   var beforeCdnRepeat=cp.Calls;
   ((UiCommandAsync)view.Vm.Cdn.RefreshCommand!).ExecuteAsync(null).GetAwaiter().GetResult();
   if(cp.Calls!=beforeCdnRepeat)throw new Exception("Duplicate CDN request");
   cp.CdnPending.SetResult(new CdnFolderContent{MaxFileSize=200_000_000});cp.CdnPending=null;
   Pump(cdnRequest);Layout(root);
   if(rp.Calls!=beforeRegistry||!cdnButton.IsEnabled)throw new Exception("CDN refresh failed");
   typeof(EmApp).GetProperty("ActiveUser")!.SetValue(app, Em.Api.Core.Models.User.Build(app, new vi_User { cUserIsAdmin=true, cUserAccount="render-admin" }));
   var beforeRegistryNuget = rp.Calls;
   np.NuPending = new TaskCompletionSource<NuPakStatus>();
   var nuRequest = ((UiCommandAsync)view.Vm.NuGet.RefreshCommand!).ExecuteAsync(null); Layout(root);
   var nuButton = buttons.Single(b=>ReferenceEquals(b.DataContext,view.Vm.NuGet));
   var nuToggle = Descendants<ToggleButton>(root).Single(b=>AutomationProperties.GetName(b)=="NuGet server enabled" && b.Visibility==Visibility.Visible);
   if(nuToggle.IsEnabled)throw new Exception("NuGet toggle enabled during refresh");
   if(nuButton.IsEnabled || !registryButton.IsEnabled)throw new Exception("NuGet busy isolation failed");
   var nuCalls=np.Calls; ((UiCommandAsync)view.Vm.NuGet.RefreshCommand!).ExecuteAsync(null).GetAwaiter().GetResult();
   if(np.Calls!=nuCalls)throw new Exception("Duplicate NuGet request");
   Save(root,$"{(dark?"dark":"light")}-nuget-busy.png");
   np.NuPending.SetResult(new(true,2,2,2,3,4,1));np.NuPending=null;Pump(nuRequest);Layout(root);
   if(nuToggle.IsChecked!=true || !nuToggle.IsEnabled)throw new Exception("NuGet toggle does not reflect on state");
   Save(root,$"{(dark?"dark":"light")}-nuget-on.png");
   if(rp.Calls!=beforeRegistryNuget || view.Vm.NuGet.Status!=HomeStatus.Ready || !view.Vm.NuGet.StorageCaption.Contains("recycle bin"))throw new Exception("NuGet refresh failed");
   np.NuEnabled=false;Pump(((UiCommandAsync)view.Vm.NuGet.RefreshCommand!).ExecuteAsync(null));Layout(root);Save(root,$"{(dark?"dark":"light")}-nuget-off.png");
   if(nuToggle.IsChecked!=false)throw new Exception("NuGet toggle does not reflect off state");
   np.Fail=true;Pump(((UiCommandAsync)view.Vm.NuGet.RefreshCommand!).ExecuteAsync(null));Layout(root);Save(root,$"{(dark?"dark":"light")}-nuget-error.png");
   if(!nuButton.IsEnabled || view.Vm.NuGet.Status!=HomeStatus.Warning)throw new Exception("NuGet failure retry failed");
   np.Fail=false;
   Pump(((UiCommandAsync)view.Vm.NuGet.RefreshCommand!).ExecuteAsync(null));
   if(!view.Vm.NuGet.ToggleCommand!.CanExecute(null))throw new Exception("Authorized toggle disabled");
   typeof(ToggleButton).GetMethod("OnClick",BindingFlags.Instance|BindingFlags.NonPublic)!.Invoke(nuToggle,null);
   Layout(root);
   if(!view.Vm.NuGet.Enabled || view.Vm.NuGet.Status!=HomeStatus.Ready || nuToggle.IsChecked!=true)throw new Exception("Home enable toggle click failed");
   np.NuEnabled=true;
   Console.WriteLine($"PASS {(dark?"dark":"light")}: home cards refresh independently, duplicate guard, storage, error/retry and NuGet toggle");
  }
 }
 static void Pump(Task task) {while(!task.IsCompleted) Application.Current.Dispatcher.Invoke(()=>{},DispatcherPriority.ApplicationIdle);task.GetAwaiter().GetResult();}
 static void Layout(FrameworkElement root){root.Measure(new Size(root.Width,root.Height));root.Arrange(new Rect(0,0,root.Width,root.Height));root.UpdateLayout();Application.Current.Dispatcher.Invoke(()=>{},DispatcherPriority.ApplicationIdle);}
 static IEnumerable<T> Descendants<T>(DependencyObject obj) where T:DependencyObject { if(obj is T found)yield return found;for(int i=0;i<VisualTreeHelper.GetChildrenCount(obj);i++)foreach(var child in Descendants<T>(VisualTreeHelper.GetChild(obj,i)))yield return child; }
 static void Save(FrameworkElement root,string name){var bmp=new RenderTargetBitmap((int)root.Width,(int)root.Height,96,96,PixelFormats.Pbgra32);bmp.Render(root);var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bmp));using var file=System.IO.File.Create(System.IO.Path.Combine(AppContext.BaseDirectory,name));encoder.Save(file);}
}
public class FakeService:DispatchProxy {
 public TaskCompletionSource<NuPakPackageInfo[]>? PackagesPending; public bool NuEnabled=true; public TaskCompletionSource<NuPakStatus>? NuPending;
 public bool ZeroFeeds; public TaskCompletionSource<NuPakFeedInfo>? FeedPending;
 public int Calls; public bool Fail; public TaskCompletionSource<CtnRootInfo[]>? Pending;
 public TaskCompletionSource<CdnFolderContent>? CdnPending;
 protected override object? Invoke(MethodInfo? method,object?[]? args) {
  Calls++;if(Fail)throw new InvalidOperationException("Synthetic unavailable");
  return method!.Name switch {
   "PostGetMeta_NuPakSetEnabled" => Task.FromResult(new NuPakStatus(NuEnabled=(bool)args![0]!,2,2,2,3,4,1)),
   "GetMeta_NuPakStatus" => NuPending?.Task ?? Task.FromResult(ZeroFeeds?new NuPakStatus(NuEnabled,0,0,0,0,0,0):new NuPakStatus(NuEnabled,2,2,2,3,4,1)),
   "GetMeta_NuPakFeedStorageSize" => Task.FromResult(new NuPakStorageInfo(10000000,2000000,3,5)),
   "GetMeta_NuPakFeeds" => Task.FromResult(ZeroFeeds?Array.Empty<NuPakFeedInfo>():new[]{new NuPakFeedInfo("a","alpha","Alpha",null,true,false,true,1,1,3,4,1),new NuPakFeedInfo("b","beta","Beta",null,false,true,false,0,0,0,0,0)}),
   "GetMeta_NuPakFeed" => (string)args![0]! == "a" && FeedPending is not null ? FeedPending.Task : Task.FromResult(new NuPakFeedInfo((string)args![0]!, (string)args[0]! == "a" ? "alpha" : "beta",(string)args[0]! == "a" ? "Alpha" : "Beta",null,true,false,true,1,1,3,4,1)),
   "GetMeta_NuPakServerAudit" => Task.FromResult(Array.Empty<ta_NuPakAudit>()),
   "GetMeta_NuPakStorageSize" => Task.FromResult(new NuPakStorageInfo(10000000,2000000,3,5)),
   "GetMeta_NuPakPrefixes" => Task.FromResult(new[]{new NuPakPrefixInfo("p","MatrixCode.","Internal packages",true,3,12000000)}),
   "GetMeta_NuPakRecycleBin" => Task.FromResult(new[]{new NuPakVersionInfo("bin","pkg","MatrixCode.Library","0.9.0","0.9.0",false,-2,2000000,"SHA512-test","build-robot",DateTime.UtcNow.AddDays(-3),DateTime.UtcNow)}),
   "GetMeta_NuPakAudit" => Task.FromResult(new[]{new ta_NuPakAudit{cNuPakAuditAt=DateTime.UtcNow,cNuPakAuditAction="Push",cNuPakAuditActorName="build-robot",cNuPakAuditResult="Success",cNuPakAuditPackage="MatrixCode.Library",cNuPakAuditVersion="1.2.0"}}),
   "GetMeta_NuPakPackages" => PackagesPending?.Task ?? Task.FromResult(new[]{new NuPakPackageInfo("pkg","MatrixCode.Library",2,10000000,"1.2.0")}),
   "GetMeta_NuPakVersions" => Task.FromResult(new[]{new NuPakVersionInfo("v","pkg","MatrixCode.Library","1.2.0","1.2.0",false,1,5000000,"SHA512-test","build-robot",DateTime.UtcNow,null)}),
   "GetMeta_NuPakPrefixAccess" => Task.FromResult(new[]{new NuPakAccessInfo("robot","build-robot","W")}),
   "GetMeta_CtnRoots" => Pending?.Task ?? Task.FromResult(new[]{new CtnRootInfo{ImageCount=3}}),
   "GetMeta_CtnStorageSize" => Task.FromResult(new CtnStorageInfo{BlobBytes=10_000_000,ManifestBytes=1000}),
   "GetMeta_CdnFolder" => CdnPending?.Task ?? Task.FromResult(new CdnFolderContent{MaxFileSize=200_000_000}),
   "GetMeta_CdnStorageSize" => Task.FromResult(new CdnStorageInfo{TotalBytes=15_000_000,FileCount=12}),
   _ => throw new NotSupportedException(method.Name)
  };
 }
}
