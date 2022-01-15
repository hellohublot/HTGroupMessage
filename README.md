- 支持 Group 进程间通信, 比如主 app 和 Today Extension 和 VPN Network Extension 三个进程之间的通信
- 单独使用 CFNotification 不能携带消息内容，所以使用 SQLite3 存储消息内容

## Usage

```ruby
pod 'HTGroupMessage', :git => 'https://github.com/hellohublot/HTGroupMessage.git'
```
```swift
let groupManager = HTGroupMessage.init('your group url')

// 发送消息到其他进程
groupManager.post('your message type', 'your message content')

// 监听其他进程发来的消息
groupManager.listen('your message type', { (messageType, messageContent) in

})
```

## Author

hellohublot, hublot@aliyun.com
