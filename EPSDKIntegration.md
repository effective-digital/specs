# EffectiveProcessesSDK Integration Guide

This guide provides a comprehensive overview of how to integrate the `EffectiveProcessesSDK` into your iOS project using CocoaPods, configure it within your `AppDelegate`, and implement required components such as `BannerView` and state handling.

## Prerequisites

- **Xcode**: Ensure you have the latest version of Xcode installed.
- **CocoaPods**: Make sure CocoaPods is installed on your machine. If not, you can install it using the following command:

  ```sh
  sudo gem install cocoapods
  ```

# Section 1 - Inital setup

## Step 1: Update the Podfile

To begin, you'll need to modify your `Podfile` to include the necessary sources and dependencies.

### Add the Source Repository

Open your `Podfile` and add the following source repository, which contains the `EffectiveProcessesSDK`:

```ruby
source 'https://github.com/effective-digital/specs.git'

target 'YourAppTargetName' do
  pod 'EffectiveProcessesSDK', '1.0.12'
end
```
### Install the Pods

After saving the `Podfile`, run the following commands to add the specified repo and install the SDK:

```bash
pod repo add edsdkdigital https://github.com/effective-digital/specs.git
pod install
```
## Step 2: Configure the SDK in AppDelegate

After installing the SDK, you need to configure it within your application’s `AppDelegate` file.

### Set the Base URL

The SDK requires a base URL for API calls. Set this base URL in the `AppDelegate`'s `didFinishLaunchingWithOptions` method:

```swift
APIConstant.BASE_URL = Configuration.config.edBaseURL
```

### Register SDK Dependencies

After setting the base URL, register the SDK dependencies by adding the following line in the same method:

```swift
EPSdkMain.registerDependancy()
```

## Step 3: Implement and Configure BannerView

The `BannerView` is a component of the `EffectiveProcessesSDK` that displays a carousel of active process instances for the user. It is important to note that `BannerView` has no fixed size, allowing you to adjust its dimensions according to your app's layout requirements. Additionally, you should implement logic to handle an empty state if no process instances are returned when fetching offers explained in *Fetch Offers section*.

### Create a BannerView Instance

Add a lazy-loaded instance of `BannerView` in your view controller or wherever you plan to use it:

```swift
private lazy var bannerview = BannerView(
    targetName: "", 
    token: "Bearer \(AccessToken())", 
    shouldCheckExpiredToken: false
)
```
- **targetName**: The target name is ***OPTIONAL***.
- **token**: The authorization token, typically a Bearer token.
- **shouldCheckExpiredToken**: A boolean that indicates whether to check for token expiration. The default value is `true`, and it checks against the `exp` property in the JWT. If your JWT does not include an expiration property, set this to `false`.


### Fetch Offers

Use the `getOffer` method to fetch offers from the server and handle the response to adjust the banner view accordingly:

```swift
bannerView.getOffer { hasOffers in
    if !hasOffers {
        // No offers available: hide the view or display an empty state
    } else {
        // Offers available: adjust constraints accordingly
    }
}
```
## ***Step 4 (OPTIONAL*)** : Register and Handle SDK State Changes
The SDK might emit various states that your application needs to respond to. This section describes how to register for these state changes. This step is ***OPTIONAL***. the library will by default present on the top active controller


The `EDStateUseCase` is observe sdk state changes:

```swift
@LazyInjected
var epState: EDStateUseCase

epState.state = { [weak self] in
    switch $0 {
    case .presentFlow(let instance):
        guard let self else { return }
       let rootVC = YourViewcontrolerThatWillPresentFlow
       let outerRouter =  EPFlowRouter(rootViewController: rootVC) // impolentation of  FlowRouter
       Resolver.resolve(EPUseCase.self).openFlow(instance, outerRouter: outerRouter, navigation: rootVC) // trigger opening the process flow
    default:
        return
    }
}
```
This block of code listens for state changes and triggers appropriate actions based on the state, such as presenting a new flow.

### Example of FlowRouter

```swift

public class EPFlowRouter: EPOuterRouter {

    init () {}
    public weak var rootViewController: UIViewController?
    public init(rootViewController: UIViewController?) {
        self.rootViewController = rootViewController
    }

    public func onFlowFinished() {
        rootViewController?.dismiss(animated: true)
    }
}
```

- **onFlowFinished**: Clean up and dismiss the presented flow when it's completed.

# Section 2 - Setup Push Notification for `EffectiveProcessesSDK`

This documentation outlines the integration of push notifications using the `NotificationManagerProtocol` in an iOS application.

## 1. Declaration and Setup

### 1.1 Declaration of `NotificationManagerProtocol`

In the `AppDelegate`, declare the `NotificationManagerProtocol` using `@LazyInjected`:

```swift
@LazyInjected
var notification: NotificationManagerProtocol
```

## 1.2 Setup in `didFinishLaunchingWithOptions`

Set up the notification manager and handle remote notifications if the app was launched due to one:

```swift
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // Setup Push Notification Manager
    self.notification.setup()

    // Check if app was launched via a remote notification
    if let userInfo = launchOptions?[.remoteNotification] as? [String: Any] {
        notification.lastUnAutherisedNotification = userInfo
    }

    return true
}
```
### Remote Notification Check

- The `launchOptions` dictionary is checked for the key `.remoteNotification`. This key is present if the app was launched in response to a push notification.

- The associated value for this key is expected to be a dictionary (`[String: Any]`), which contains the data that was sent with the notification.

### Assigning the Notification Data

- If the app was indeed launched by a remote notification, the `userInfo` dictionary (which contains all the relevant notification data) is assigned to `notification.lastUnAutherisedNotification`.

- This assignment stores the notification data in the `NotificationManagerProtocol` under `lastUnAutherisedNotification`. After a successful login, when the `BannerView` is initiated with the token, it will automatically trigger the process based on the information stored in `lastUnAutherisedNotification`.




## 2. Handling Remote Notifications

This section outlines device token registration with Firebase and processing incoming notifications.

### 2.1 Device Token Registration with Firebase

Register the device token with Firebase and store the FCM token:

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Messaging.messaging().apnsToken = deviceToken
    
    if let token = Messaging.messaging().fcmToken {
        notification.fcmToken = token
    }
}
```
### 2.2 Implementing `UNUserNotificationCenterDelegate`

To handle notifications while the app is in the foreground, implement the `userNotificationCenter(_:willPresent:withCompletionHandler:)` method:

```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
    var notificationManager: NotificationManagerProtocol = Resolver.resolve()
    let dict = notification.request.content.userInfo
    
    notificationManager.lastUnAutherisedNotification = dict
    notificationManager.onNotificationRecived?(dict)

    completionHandler([.alert, .sound, .badge])
}

```
In this method:

The notification manager handles the received notification.
The notification's userInfo is passed to the manager for further processing.
The completionHandler is called with options to present the alert, play a sound, and show a badge.


### 2.3 Handling User Interaction with Notifications


Implement the `userNotificationCenter(_:didReceive:withCompletionHandler:)` method to handle responses to notifications:

The app must handle notifications by ensuring that the user's session is active and, where applicable, by checking the expiry of the JWT token. If the JWT token includes an `exp` property, the library provides a convenient method to check if the token has expired. However, if the token does not include this property, or for additional logic, the app must manually handle the session's validity. Here’s how this can be implemented:


```swift
public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let userInfo = response.notification.request.content.userInfo

    if !APIConstant.TOKEN_EXPIRED { // handle custom logic
        lastUnAutherisedNotification = nil
        let instanceId = userInfo["instanceId"] as? String
        
        Resolver.resolve(EPUseCase.self).startOrResumeProcess(instanceId ?? "") { result in
            switch result {
            case .success(let instance):
                Resolver.resolve(EDStateUseCase.self).state?(.presentFlow(instance))
            case .failure(_):
                break
            }
        }
    }
    
    completionHandler()
}
```
- **Starting or Resuming a Process**: The app uses the `EPUseCase` to start or resume the process based on the `instanceId`. This operation is asynchronous, and the result is handled via a completion callback:

- **Success Handling**: If the process is successfully resumed or started, the app updates its state by calling the `EDStateUseCase` to transition to the appropriate screen for that process instance.

- **Failure Handling**: If the process fails to resume or start, the failure is silently ignored, and no further action is taken.

# Section 3 - Open Process Flow Using a ProcessInstance

This example demonstrates how to open a process flow in your application using the `openFlow(_ instance:outerRouter:navigation:)` method provided by `EPUseCase`. This method is used to initiate a process flow, which is a series of steps or screens that guide the user through a specific task or workflow.

## Dependencies

Before diving into the code, ensure that the following dependencies are correctly set up in your project:

- **EPUseCase**: The use case responsible for managing the process flow logic.
- **EPOuterRouter**: A router that handles navigation and routing outside the specific flow.
- **ProcessInstance**: A model representing the process instance, containing all the necessary data to drive the flow.

## Example Implementation

```swift
import UIKit
import Resolver

class MyViewController: UIViewController {
    
    // Injecting EPUseCase using a dependency injection framework
    @LazyInjected var epUseCase: EPUseCase
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a ProcessInstance with minimal data (only id and action)
        let processInstance = ProcessInstance(
            id: "12345",                    // Unique identifier for the process instance
            action: "startProcess"          // Action that triggers the process
        )
        
        // Initialize an EPOuterRouter with the current view controller as the root
        let outerRouter = EPOuterRouter(rootViewController: self)
        
        // Call the openFlow method to present the process flow
        epUseCase.openFlow(processInstance, outerRouter: outerRouter, navigation: self)
    }
}
```

# Section 4 - Retrieving and Managing Context Processes

Retrieve context processes for a specific context name and start or resume one, updating the flow state accordingly.

Usage Example

```swift
import Resolver

// Step 1: Retrieve context processes for a specific context name
Resolver.resolve(EPUseCase.self).getContextProcesses(for: "account", checkTokenExpired: true) { result in
    switch result {
    case .success(let list):
        // Step 2: Start or resume the first process in the list
        if let firstProcess = list.first {
            Resolver.resolve(EPUseCase.self).startOrResumeContextProcess(
                name: firstProcess.name,
                data: ["accountId": "482394293423489", "iban": "SI5640294520495870"],
                checkTokenExpired: false
            ) { processResult in
                switch processResult {
                case .success(let instance):
                    // Update the flow state to open on top of the current context
                    Resolver.resolve(EDStateUseCase.self).state?(.presentFlow(instance))
                case .failure(let error):
                    // Handle the error (e.g., log or show an alert)
                    print("Failed to start or resume process: \(error)")
                }
            }
        }
    case .failure(let error):
        // Handle the error from getting context processes
        print("Failed to get context processes: \(error)")
    }
}
```

## Key Points

### Retrieve Context Processes:
- Use `getContextProcesses(for:checkTokenExpired:callback:)` in `EPUseCase` to fetch processes related to the specified context name.
- Handle the result to decide on further actions.

### Start or Resume a Process:
- Use `startOrResumeContextProcess(name:data:checkTokenExpired:callback:)` in `EPUseCase` with the selected process.
- Update the flow state to ensure the process appears on top of the current application context.

### Error Handling:
- Implement appropriate error handling at each step to ensure a smooth user experience.

## Version 1.0.14 

### 1. Breaking Changes - Retrieve Context Processes 

- In version 14 of the EffectiveProcessesSDK, the getContextProcesses method has been updated with the following key changes:

Updated Method

```swift
func getContextProcesses(
    for name: String,
    query: [String: String]? = nil, 
    checkTokenExpired: Bool, 
    callback: @escaping (EffectiveProcessesSDK.Result<EffectiveProcessesSDK.ContextFlows>) -> Void
)
```
### Key Changes:

### New query Parameter:
Allows you to pass optional query parameters for filtering (e.g., status, process type).

Example Usage

```swift
epUseCase.getContextProcesses(for: "exampleContext", query: ["status": "active"], checkTokenExpired: true) { result in
    switch result {
    case .success(let contextFlows):
        let processes = contextFlows.processInstances
        // Handle processes
    case .failure(let error):
        // Handle error
    }
}
```
This update improves flexibility with query filters and enhances error handling with the Result type.

### 2. New Functionality: In-App Session Logout Handling

To handle a session logout while a process is active, you can trigger the logout action using the following code:

```swift
Resolver.resolve(EDStateUseCase.self).state?(.logedOut)
```
This command resolves the EDStateUseCase and invokes the .logOut state, ensuring that the user is logged out even if a process is currently active.


Breaking Changes in EPSdkMain - 28.02.2025.

# Breaking Changes

1. **APIConstant Assignments Removed (Deprecated)**

The following direct assignments are deprecated and should no longer be used in `EPSdkMain`. Use `EPSDK.Configuration` instead:

swift
@available(, deprecated, message: "Use EPSDK.Configuration instead")
public static var TOKEN = ""
@available(, deprecated, message: "Use EPSDK.Configuration instead")
public static var APP_UNIQUE_ID: String = ""
@available(, deprecated, message: "Use EPSDK.Configuration instead")
public static var SHOULD_CHECK_TOKEN_EXPIRED: Bool = true


These values are now encapsulated in the new `EPSDK.Configuration` struct.

2. **Initialization Changes**

`init` now requires a `Configuration` object instead of multiple parameters.

**Old Initialization:**
```swift
let banner = .init(targetName: String, token: String, shouldCheckExpiredToken: Bool)
```swift


**New Initialization:**

```swift
let config = EPSDK.Configuration.Builder()
.setUniqueID("123")
.setToken("abc")
.setBaseURL("https:///...")  // optional default will be used
.setPinnedPublicKeyHashes("")  // optional default will be used
.setShouldCheckTokenExpired(true)  // optional default will be used that is false this is for session mgmt
.build()
let banner = .init(configuration: config)
```swift

### Steps to Upgrade

- Replace `.init` with the updated version that accepts a `Configuration` object.
- Update all initializations to use the new `EPSDK.Configuration.Builder()`.
- Remove direct usage of `APIConstant` values. Instead, use the `Configuration` object passed during initialization.method.


If u need to use unatuhenticated features from SDK u have to do following to set custum baseURL for EDFlow:

swift
let config = EPSDK.Configuration.Builder()
.setBaseURL("https:///...")
.setPinnedPublicKeyHashes("")
.build()

 Resolver.register { config.epUseCase }
```

## 📦 EffectiveProcessesSDK Integration Guide  
**Updated: May 10, 2025**

> ⚠️ **Breaking Change Notice:**  
> As of the latest version of `EffectiveProcessesSDK`, the legacy `BannerView` initializer has been **removed**.  
> Any usage of the old API will result in a **compilation error**.  
> You must migrate to the new `BannerComponentFactoryV2` API to ensure compatibility.

### Step 1 🔤 Required: Add Font to the Main App Target and Register in `Info.plist`

To enable icon rendering via the SDK’s bundled font, ensure the following:

- ✅ The font file (`Font Awesome 6 Free-Solid-900.otf`) need to be  **added to the main app target**.
- ✅ It is properly declared in the app’s `Info.plist` file:

```xml
<key>UIAppFonts</key>
<array>
    <string>Font Awesome 6 Free-Solid-900.otf</string>
</array>
```

## Step 2: Implement and re-Configure BannerView
# ⚠️ Important: REMOVAL API Notice – What to Use Instead

The following usage of `BannerView` is **removed** and cant be no longer be used:

```swift
// ❌ REMOVED - do not use
private lazy var bannerView = BannerView(
    targetName: "", 
    token: "Bearer \(AccessToken())", 
    shouldCheckExpiredToken: false....
)
```

### ✅ Use This Instead

Replace the above with the updated `BannerComponentFactoryV2.PresentOffersBannerView` API:

# Banner Component Implementation Guide

```swift
// 1. Configure SDK
let config = EPSDK.Configuration.Builder()
    .setUniqueID("{{targetName}}")
    .setBaseURL("{{BASEURL}}/dev-process-engine")
    .setToken("{{token}}")
    .build()

// 2. Initialize Banner
banner = BannerComponentFactoryV2.PresentOffersBannerView(
    for: config,
    cardHeight: 150,
    onEmpty: { [weak self] in
        print("Banner: No offers available to display")
        self?.handleEmptyBanner()
    },
    onError: { [weak self] error in
        print("Banner Error: \(error.localizedDescription)")
        dump(error)
        self?.handleBannerError(error)
    }
)
```

## Required Parameters
- `config`: EPSDK configuration object
- `cardHeight`: Banner height in points
- `onEmpty`: Optional Handler for no offers state
- `onError`: Optional Handler for error states

## Required Handlers
```swift
private func handleEmptyBanner() {
    // Handle no offers state
    banner.isHidden = true
}

private func handleBannerError(_ error: Error) {
    // Handle error state
    banner.isHidden = true
}
```
# Localizing Keyboard toolbar "Done" Button

Add to your app's `Localizable.strings` files:

```strings
"Done" = "Done"; // English
"Done" = "Fertig"; // German
"Done" = "Terminé"; // French
"Done" = "Hecho"; // Spanish
"Done" = "Fatto"; // Italian
```

Place in respective language folders (e.g., `en.lproj`, `de.lproj`, etc.). Missing translations will fall back to English "Done".

# Logger Levels Guide

## Log Level Hierarchy
```
.none < .info < .warning < .error < .success
```

## Setting Minimum Log Level
```swift
// In AppDelegate.swift
Logger.minimumLogLevel = .info  // Shows all messages
Logger.minimumLogLevel = .warning  // Shows warnings, errors, and successes
Logger.minimumLogLevel = .error  // Shows only errors
Logger.minimumLogLevel = .succes  // Shows only success
Logger.minimumLogLevel = .none  // Shows nothing
```

## Quick Reference

| Level    | When to Use                          | Example                                    |
|----------|--------------------------------------|--------------------------------------------|
| .info    | General information, debugging       | "View loaded", "API request started"       |
| .warning | Potential issues, non-critical       | "Token expiring", "Slow response"          |
| .error   | Actual errors, failures              | "Network failed", "Auth failed"            |
| .success | Successful operations                | "Data saved", "Login successful"           |
| .none    | Disable all logging                  | Use in production to disable logging       |


## ⚠️ Breaking Change Notice

As of the latest release, the `EPSdkMain.registerDependancy` initializer has been **removed**.  
Any usage of the old API will now result in a **compilation error**.

---

### 🔁 Migration Guide – Use This Instead

```swift
EPSdkMain.registerDependancy(
    setBaseURL: BASE_URL,
    setPinnedPublicKeyHashes: OPTIONAL?
)
```
### 🔧 New Behavior Summary

- `setBaseURL` is **mandatory**.  
  You no longer need to set it within the banner config builder  
  (though you can still override it if needed).

- `setPinnedPublicKeyHashes` is **optional**.  
  Use this **only** if the base server is changed.  
  In that case, extract SSL pinned public key hashes using the script:  
  `/extract_ssl_pinning_hash_mobile.sh`
  Use this **only** if you're changing the base server.

# Flow Auto-Redirect Handler Implementation Guide

## Overview

This guide provides detailed implementation examples for the Flow Auto-Redirect Handler. The handler manages automatic flow transitions in your app, with support for various flow steps and a smooth transition experience.

## Implementation Examples

### 1. Basic Setup


```swift
// In your AppDelegate or SceneDelegate
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Set up sdk
    EPSdkMain.registerDependancy(setBaseURL: "")
    
    // Set up the sdk flow router handler
    var flowRouter: EPOuterRouter = Resolver.resolve()
    flowRouter.onAutoRedirectHandler = { payload, transitionId, processId, requestBlock in
        DemoFlowRouter.onAutoRedirectAndContinueFlow(
            payload: payload,
            transitionId: transitionId,
            procesid: processId,
            requestBlock: requestBlock
        )
    }
    
    return true
}
```

### 2. Adding a New Flow Step

To add a new flow step, follow these steps:

1. Add the step to the `FlowStep` enum:
```swift
enum FlowStep: String {
    case sumsubVerif = "SUMSUB_VERIF"
    case webView = "WEB_VIEW"
    case yourNewStep = "YOUR_NEW_STEP"  // Add your new step
}
```

2. Create a processor for your step:
```swift
class YourNewStepProcessor {
    static func process(payload: String, completion: @escaping ([String: Any]) -> Void) {
        // Parse your payload
        guard let parsedValues = payload.parse(keys: "stepName", "yourParam1", "yourParam2") else {
            Logger.log("Failed to parse payload", level: .error)
            return
        }
        
        // Your processing logic here
        let result = [
            "status": "completed",
            "yourParam1": parsedValues.values["yourParam1"] ?? "",
            "yourParam2": parsedValues.values["yourParam2"] ?? ""
        ]
        
        completion(result)
    }
}
```

3. Add the handler in `DemoFlowRouter`:
```swift
private static func handleFlowStep(
    _ step: FlowStep,
    parsedValues: [String: String],
    payload: String,
    transitionId: String,
    procesid: String,
    requestBlock: @escaping RequestBlock
) {
    switch step {
    case .sumsubVerif:
        handleSumSubVerif(payload: payload, transitionId: transitionId, procesid: procesid, requestBlock: requestBlock)
    case .webView:
        handleWebView(secondParams: parsedValues["secondParams"], transitionId: transitionId, procesid: procesid, requestBlock: requestBlock)
    case .yourNewStep:
        handleYourNewStep(payload: payload, transitionId: transitionId, procesid: procesid, requestBlock: requestBlock)
    }
}

private static func handleYourNewStep(
    payload: String,
    transitionId: String,
    procesid: String,
    requestBlock: @escaping RequestBlock
) {
    YourNewStepProcessor.process(payload: payload) { result in
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: []) else {
            Logger.log("Failed to serialize result to JSON", level: .error)
            return
        }
        
        continueFlow(
            transitionId: transitionId,
            procesid: procesid,
            data: data,
            requestBlock: requestBlock
        )
    }
}
```

### 3. Error Handling Examples

```swift
// In your processor
class YourProcessor {
    static func process(payload: String, completion: @escaping ([String: Any]) -> Void) {
        // Parse payload
        guard let parsedValues = payload.parse(keys: "stepName", "param1") else {
            Logger.log("Failed to parse payload", level: .error)
            completion(["error": "Invalid payload format"])
            return
        }
        
        // Validate required parameters
        guard let param1 = parsedValues.values["param1"], !param1.isEmpty else {
            Logger.log("Missing required parameter: param1", level: .error)
            completion(["error": "Missing required parameter"])
            return
        }
        
        // Your processing logic
        do {
            let result = try processYourLogic(param1: param1)
            completion(result)
        } catch {
            Logger.log("Processing failed: \(error)", level: .error)
            completion(["error": error.localizedDescription])
        }
    }
}
```

### 4. Flow Continuation Examples

```swift
// In your flow handler
private static func continueFlow(
    transitionId: String,
    procesid: String,
    data: Data,
    requestBlock: @escaping RequestBlock
) {
    requestBlock(transitionId, procesid, data) { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let instance):
                Logger.log("Flow continuation succeeded", level: .info)
                hideTransitionScreen {
                    Resolver.resolve(EDStateUseCase.self).state?(.presentFlow(instance))
                }
            case .failure(let error):
                Logger.log("Flow continuation failed: \(error)", level: .error)
                hideTransitionScreen {
                    // Handle error (e.g., show error alert)
                    showErrorAlert(error: error)
                }
            }
        }
    }
}

private static func showErrorAlert(error: Error) {
    let alert = UIAlertController(
        title: "Error",
        message: error.localizedDescription,
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    UIApplication.shared.topMostController?.present(alert, animated: true)
}
```
### 5. Parsing the Payload

```swift
let parsedValues = payload.parse(keys: "stepName", "token", "clientID")
```
The `parse` method implementation:

```swift
extension String {
    func parse(keys: String...) -> (values: [String: String])? {
        guard let data = Data(base64Encoded: self),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var values: [String: String] = [:]
        for key in keys {
            if let value = json[key] as? String {
                values[key] = value
            }
        }
        return values.isEmpty ? nil : (values: values)
    }
}
```

## Payload Examples

### SumSub Verification
```json
{
  "stepName": "SUMSUB_VERIF",
  "secondParams": "verification_params",
  "clientID": "your_client_id"
}
```

### Web View
```json
{
  "stepName": "WEB_VIEW",
  "secondParams": "https://your-web-view-url.com",
  "clientID": "your_client_id"
}
```

### Custom Step
```json
{
  "stepName": "YOUR_NEW_STEP",
  "yourParam1": "value1",
  "yourParam2": "value2",
  "clientID": "your_client_id"
}
```

## Complete Implementation

### TransitionViewController

The `TransitionViewController` is a simple loading screen that provides visual feedback during flow transitions. It shows a centered activity indicator on a full-screen background.

```swift
// MARK: - Transition View Controller
private class TransitionViewController: UIViewController {
    private let activityIndicator: UIActivityIndicatorView

    init() {
        self.activityIndicator = UIActivityIndicatorView(style: .large)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        activityIndicator.startAnimating()
    }
}
```

The `TransitionViewController` serves several important purposes:

1. **Visual Feedback**: Shows users that something is happening during flow transitions
2. **Prevent User Interaction**: Blocks user interaction while processing flow steps
3. **Smooth Transitions**: Provides a seamless experience between different flow states
4. **Loading State**: Indicates that the app is working on processing the current step

It's used in the `DemoFlowRouter` to:
- Show during async operations
- Hide when operations complete
- Present full screen to block user interaction
- Provide consistent loading experience

### DemoFlowRouter Implementation

```swift
// MARK: - Flow Step Types
enum FlowStep: String {
    case sumsubVerif = "SUMSUB_VERIF"
    case webView = "WEB_VIEW"
}

// MARK: - Flow Result
enum FlowResult {
    case success(ProcessInstance)
    case failure(Error)
}

// MARK: - DemoFlowRouter
/// Handles automatic redirection and flow continuation in a demo scenario.
class DemoFlowRouter {
    private static var transitionVC: TransitionViewController?

    /// Handles auto-redirect and continues the flow process.
    /// - Parameters:
    ///   - payload: Base64 encoded payload string.
    ///   - transitionId: Transition ID for the flow.
    ///   - procesid: Process ID for the current flow.
    ///   - requestBlock: Block to process the request and handle the flow transition.
    public static func onAutoRedirectAndContinueFlow(
        payload: String,
        transitionId: String,
        procesid: String,
        requestBlock: @escaping RequestBlock
    ) {
        Logger.log("Starting onAutoRedirectAndContinueFlow", level: .info)

        guard let parsedValues = payload.parse(keys: "stepName", "secondParams", "clientID") else {
            Logger.log("Failed to parse payload", level: .error)
            return
        }

        guard let stepName = parsedValues.values["stepName"],
            let flowStep = FlowStep(rawValue: stepName)
        else {
            Logger.log(
                "Invalid or unsupported step name: \(parsedValues.values["stepName"] ?? "nil")",
                level: .error)
            return
        }

        dismissTopController {
            self.handleFlowStep(
                flowStep,
                parsedValues: parsedValues.values,
                payload: payload,
                transitionId: transitionId,
                procesid: procesid,
                requestBlock: requestBlock
            )
        }
    }

    // MARK: - Private Methods

    private static func dismissTopController(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            UIApplication.shared.topMostController?.dismiss(animated: false) {
                showTransitionScreen {
                    completion()
                }
            }
        }
    }

    private static func showTransitionScreen(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            transitionVC = TransitionViewController()
            transitionVC?.modalPresentationStyle = .fullScreen
            UIApplication.shared.topMostController?.present(transitionVC!, animated: false) {
                completion()
            }
        }
    }

    private static func hideTransitionScreen(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            transitionVC?.dismiss(animated: false) {
                self.transitionVC = nil
                completion()
            }
        }
    }

    private static func handleFlowStep(
        _ step: FlowStep,
        parsedValues: [String: String],
        payload: String,
        transitionId: String,
        procesid: String,
        requestBlock: @escaping RequestBlock
    ) {
        switch step {
        case .sumsubVerif:
            handleSumSubVerif(
                payload: payload,
                transitionId: transitionId,
                procesid: procesid,
                requestBlock: requestBlock
            )
        case .webView:
            handleWebView(
                secondParams: parsedValues["secondParams"],
                transitionId: transitionId,
                procesid: procesid,
                requestBlock: requestBlock
            )
        }
    }

    private static func handleSumSubVerif(
        payload: String,
        transitionId: String,
        procesid: String,
        requestBlock: @escaping RequestBlock
    ) {
        Logger.log("Processing SumSub verification", level: .info)

        SumSubProcessor.process(payload: payload) { map in
            guard let data = try? JSONSerialization.data(withJSONObject: map, options: []) else {
                Logger.log("Failed to serialize processed payload to JSON", level: .error)
                return
            }

            continueFlow(
                transitionId: transitionId,
                procesid: procesid,
                data: data,
                requestBlock: requestBlock
            )
        }
    }

    private static func handleWebView(
        secondParams: String?,
        transitionId: String,
        procesid: String,
        requestBlock: @escaping RequestBlock
    ) {
        guard let secondParams = secondParams else {
            Logger.log("Missing secondParams for WebView step", level: .error)
            return
        }

        WebRedirectProcessor.process(webViewURL: secondParams) { map in
            guard let data = try? JSONSerialization.data(withJSONObject: map, options: []) else {
                Logger.log("Failed to serialize WebView data to JSON", level: .error)
                return
            }

            continueFlow(
                transitionId: transitionId,
                procesid: procesid,
                data: data,
                requestBlock: requestBlock
            )
        }
    }

    private static func continueFlow(
        transitionId: String,
        procesid: String,
        data: Data,
        requestBlock: @escaping RequestBlock
    ) {
        requestBlock(transitionId, procesid, data) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let instance):
                    Logger.log("Flow continuation succeeded", level: .info)
                    hideTransitionScreen {
                        Resolver.resolve(EDStateUseCase.self).state?(.presentFlow(instance))
                    }
                case .failure(let error):
                    Logger.log("Flow continuation failed with error: \(error)", level: .error)
                    hideTransitionScreen {}
                }
            }
        }
    }
}

import SwiftUI
import UIKit
import WebKit

class WebRedirectController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    private var activityIndicator: UIActivityIndicatorView
    private var loadingContainer: UIView
    var config: WebRedirectConfig?
    private var checkTimer: Timer?
    private var closeButton: UIButton!
    private var onClose: (() -> Void)?

    init(config: WebRedirectConfig, onClose: (() -> Void)? = nil) {
        self.config = config
        self.onClose = onClose
        self.activityIndicator = UIActivityIndicatorView(style: .large)
        self.loadingContainer = UIView()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct WebRedirectConfig {
        var webViewURL: String?  // WEB URL - web page to be openned

        static func parsePayload(_ payload: String) -> WebRedirectConfig {
            let components = payload.components(separatedBy: ";")
            guard components.count >= 4 else {
                fatalError("Invalid payload format")
            }

            // First component should be "WEB_VIEW"
            guard components[0] == "WEB_VIEW" else {
                fatalError("Invalid request type")
            }

            return WebRedirectConfig(
                webViewURL: components[1]
            )
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        guard let uri = config?.webViewURL,
            let url = URL(string: uri)
        else {
            fatalError("no uri or url .. sorry")
        }
        addWebView(url: url)
        setupCloseButton()
        removeCookies()
    }

    func addWebView(url: URL) {
        webView = WKWebView(frame: view.bounds, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        view.addSubview(webView)

        let request = URLRequest(url: url)
        webView.load(request)
    }

    private func showLoading() {
        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        activityIndicator.startAnimating()
    }

    private func hideLoading() {
        activityIndicator.stopAnimating()
        activityIndicator.removeFromSuperview()
    }

    func removeCookies() {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                cookieStore.delete(cookie)
            }
        }
    }

    private func setupCloseButton() {
        closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = .black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        closeButton.addAction(
            UIAction(handler: { [weak self] _ in
                self?.closeButtonTapped()
            }), for: .touchUpInside)
    }

    private func closeButtonTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onClose?()
        }
    }

    // MARK: - WKNavigationDelegate methods

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        hideLoading()
    }
}
class WebRedirectProcessor {
    static func process(webViewURL: String?, completion: @escaping ([String: String]) -> Void) {
        let config = WebRedirectController.WebRedirectConfig(webViewURL: webViewURL)
        
        let controller = WebRedirectController(config: config) {
            let processedParameters = ["": ""]
            DispatchQueue.main.asyncAfter(deadline: .now()){
                completion(processedParameters)
                Logger.log("WebRedirectProcessor: Web view has been closed manually with parameters: \(processedParameters)", level: .info)
            }
        }
        
        // Present the controller
        DispatchQueue.main.async {
            if let topViewController =  UIApplication.shared.topMostController {
                controller.modalPresentationStyle = .fullScreen
                controller.modalTransitionStyle = .crossDissolve
                topViewController.present(controller, animated: true)
            }
        }
    }
}
```
