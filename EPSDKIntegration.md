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
