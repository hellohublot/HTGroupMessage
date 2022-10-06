## Features

- Support group out-process communication, such as the communication between the main app and the three processes of Today Extension and VPN Network Extension
- CFNotification alone cannot take the message content, so use SQLite3 to store the message content

## Usage

```ruby
pod 'HTGroupMessage', :git => 'https://github.com/hellohublot/HTGroupMessage.git'
```
```swift
let groupManager = HTGroupMessage.init('your group url')

// send message to other process
groupManager.post('your message type', 'your message content')

// receive message from other process
groupManager.listen('your message type', { (messageType, messageContent) in

})
```

## Author

hellohublot, hublot@aliyun.com
