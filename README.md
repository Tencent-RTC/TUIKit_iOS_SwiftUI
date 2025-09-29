# TUIKit iOS SwiftUI

This document introduces **how to quickly run the TUIKit SwiftUI demo.**

> Please Attention: 
> In respect for the copyright of the emoji design, This project does not include the cutouts of large emoji elements. Please replace them with your own designed or copyrighted emoji packs before the official launch for commercial use. The default small yellow face emoji pack is copyrighted by Tencent Cloud and can be authorized for a fee. If you wish to obtain authorization, please [Contact Us](https://trtc.io/contact).
> 
> <img src="https://qcloudimg.tencent-cloud.cn/image/document/6438e8feb7bba909511e0d798dfaf91d.png" width="300px" />
> 


### Step 1. Create an App
1. Log in to the [Chat Console](https://console.trtc.io/). If you already have an app, record its SDKAppID.
2. On the **Application List** page, click **Create Application**.
3. In the **Create Application** dialog box, enter the app information and click **Confirm**.
> After the app is created, an app ID (SDKAppID) will be automatically generated, which should be noted down.

### Step 2: Obtain Key Information

1. Click **Application Configuration** in the row of the target app to enter the app details page.
2. Click **View Key** and copy and save the key information.
> Please store the key information properly to prevent leakage.

### Step 3: Download and Configure the Demo Source Code

1. Clone this TUIKit_iOS_SwiftUI project.
2. Open the project in the terminal directory and find the `GenerateTestUserSig.swift` file.
3. Set relevant parameters in the `GenerateTestUserSig.swift` file:

- SDKAPPID: set it to the SDKAppID obtained in [Step 1](#step1).
- SECRETKEY: enter the key obtained in [Step 2](#step2).

<img src="https://sdk-im-1252463788.cos.ap-hongkong.myqcloud.com/tools/resource/chat/SDKAppID_SecretKey_SwiftUI.png" width="800"/>


> In this document, the method to obtain UserSig is to configure a SECRETKEY in the client code. In this method, the SECRETKEY is vulnerable to decompilation and reverse engineering. Once your SECRETKEY is leaked, attackers can steal your Tencent Cloud traffic. Therefore, **this method is only suitable for locally running a demo project and feature debugging**.
> The correct `UserSig` distribution method is to integrate the calculation code of `UserSig` into your server and provide an application-oriented API. When `UserSig` is needed, your app can send a request to the business server for a dynamic `UserSig`. For more information, please see [How do I calculate UserSig on the server?](https://trtc.io/document/34385?product=chat&menulabel=serverapis).

### Step 4: Compile and Run the Demo
1. Run the following command on the terminal to check the pod version:
```objectivec
pod --version
```
If the system indicates that no pod exists or that the pod version is earlier than 1.7.5, run the following commands to install the latest pod.
```
// Change sources.
gem sources --remove https://rubygems.org/
gem sources --add https://gems.ruby-china.com/
// Install pods.
sudo gem install cocoapods -n /usr/local/bin
// If multiple versions of Xcode are installed, run the following command to choose an Xcode version (usually the latest one):
sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer
// Update the local pod library.
pod setup
```
2. Run the following commands on the terminal to load the library.
```
cd chat/demo
pod install
```
3. If installation fails, run the following command to update the local CocoaPods repository list:
```
pod repo update
```
4. Execute the following command to update the Pod version of the component library:
```
pod update
```
5. Go to the chat/demo folder and open `ChatDemo.xcworkspace` to compile and run the demo.

When you run it successfully, you'll see this UI:

<img src="https://sdk-im-1252463788.cos.ap-hongkong.myqcloud.com/tools/resource/chat/TUIKit_iOS_SwiftUI.png" width="300" style="border: 2px solid #eeeeee;"/>