# EffectiveProcessesSDK Integration Guide

This guide provides a comprehensive overview of how to integrate the `EffectiveProcessesSDK` into your iOS project using CocoaPods, configure it within your `AppDelegate`, and implement required components such as `BannerView` and state handling.

## Prerequisites

- **Xcode**: Ensure you have the latest version of Xcode installed.
- **CocoaPods**: Make sure CocoaPods is installed on your machine. If not, you can install it using the following command:

  ```sh
  sudo gem install cocoapods
  ```


## Step 1: Update the Podfile

To begin, you'll need to modify your `Podfile` to include the necessary sources and dependencies.

### Add the Source Repository

Open your `Podfile` and add the following source repository, which contains the `EffectiveProcessesSDK`:

```ruby
source 'https://github.com/effective-digital/specs.git'
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

`BannerView` is an important component of the `EffectiveProcessesSDK`. Follow these steps to implement and configure it within your project.

### Create a BannerView Instance

Add a lazy-loaded instance of `BannerView` in your view controller or wherever you plan to use it:

```swift
private lazy var bannerview = BannerView(
    targetName: "", 
    token: "Bearer \(TSL.accessToken())", 
    shouldCheckExpiredToken: false
)
```
- **targetName**: The target name to be specified.
- **token**: Authorization token, typically a Bearer token.
- **shouldCheckExpiredToken**: A boolean indicating whether to check for token expiration.

### Fetch Offers

Use the `getOffer` method to fetch offers from the server and handle the response to adjust the banner view accordingly:

```swift
bannerview.getOffer { offers in
    if offers.isEmpty {
        // Handle empty offers scenario
    } else {
        // Handle non empty offers scenario
    }
}
```
## Step 4: Register and Handle SDK State Changes

The SDK might emit various states that your application needs to respond to. This section describes how to register for these state changes.

### Inject and Observe State

Use Dependency Injection to inject the `EDStateUseCase` and observe its state changes:

```swift
@LazyInjected
var epState: EDStateUseCase

epState.state = { [weak self] in
    switch $0 {
    case .presentFlow(let instance):
        guard let self else { return }
        self.presentFlow(instance, outerRouter: self.outerRouter, navigation: self.router.toPresent())
    default:
        return
    }
}
```
This block of code listens for state changes and triggers appropriate actions based on the state, such as presenting a new flow.

## Step 5: Implement Flow Presentation Logic

When the SDK requires your application to present a new flow, you must handle this properly to ensure a smooth user experience.

### Present the Flow

Implement the `presentFlow` method to present a new flow when triggered by the SDK:

```swift
func presentFlow(_ instance: ProcessInstance, outerRouter: EPOuterRouter, navigation: UIViewController?) {
    DispatchQueue.main.async {
        let flowNavigation = UINavigationController()
        let stepsRouter: StepsRouter?  = StepsRouter(rootViewController: flowNavigation)
        Resolver.register { outerRouter }.scope(Resolver.unique)
        Resolver.register { stepsRouter }
        let controller = EPJourney.screen(instance)(outerRouter)(flowNavigation)
        flowNavigation.viewControllers = [controller]
        flowNavigation.modalPresentationStyle = .fullScreen
        flowNavigation.setNavigationBarHidden(true, animated: false)
        navigation?.present(flowNavigation, animated: true, completion: nil)
    }
}
```
- **instance**: The process instance received from the SDK.
- **outerRouter**: The outer router that handles the navigation logic.
- **navigation**: The current `UIViewController` responsible for presenting the flow.

## Step 6: Register the Router

To manage the navigation and flow within your application, you'll need to register an instance of `EPFlowRouter`.

### Create and Register EPFlowRouter

Initialize and register `EPFlowRouter` to handle navigation changes and listen for flow completions:

```swift
lazy var outerRouter: EPOuterRouter = EPFlowRouter(rootViewController: self.router.toPresent())

public class EPFlowRouter: EPOuterRouter {
    public func onFlowAutoRedirect() {}

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
- **onFlowAutoRedirect**: Handle any automatic redirects within the flow.
- **onFlowFinished**: Clean up and dismiss the presented flow when it's completed.