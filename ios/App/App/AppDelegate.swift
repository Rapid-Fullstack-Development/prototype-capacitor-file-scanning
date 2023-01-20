import UIKit
import Capacitor
import BackgroundTasks

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    //
    // https://stackoverflow.com/a/68736333
    // https://stackoverflow.com/a/58101161
    // https://stackoverflow.com/a/61929751
    // https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler
    // https://stackoverflow.com/a/61480850
    // https://www.andyibanez.com/posts/modern-background-tasks-ios13/
    // https://developer.apple.com/documentation/backgroundtasks/starting_and_terminating_tasks_during_development
    let id = "com.ash.capacitor-file-scanning-prototype"
    BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
      // To run/debug this task:
      // - set a breakpoint at the bottom of "init"
      // - hit the breakpoint
      // - enter into the debugger:
      //     e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.ash.iOS-file-scanning-prototype.uploader"]
      // - resume the debugger and the task should kick off.
      let mediaUploader = MediaUploader()
      mediaUploader.scanMedia()
    }
    
    let request = BGProcessingTaskRequest(identifier: id)
    // request.requiresExternalPower = true
    // request.requiresNetworkConnectivity = true
    do {
      try BGTaskScheduler.shared.submit(request)
    }
    catch {
      print(error)
    }
    
    print("Submitted task")
    
    //
    // Do the scanning directly until we put the app in the background.
    //
    let mediaUploader = MediaUploader()
    mediaUploader.scanMedia()
    
    return true
  }
  
  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
  }
  
  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }
  
  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }
  
  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
  
  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    // Called when the app was launched with a url. Feel free to add additional processing here,
    // but if you want the App API to support tracking app url opens, make sure to keep this call
    return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
  }
  
  func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    // Called when the app was launched with an activity, including Universal Links.
    // Feel free to add additional processing here, but if you want the App API to support
    // tracking app url opens, make sure to keep this call
    return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
  
}
