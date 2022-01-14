//
//  HTGroupMessage.swift
//  HTGroupMessage
//
//  Created by hublot on 2018/2/9.
//

import UIKit
import SQLite3

let center = CFNotificationCenterGetDarwinNotifyCenter()

let notifacationIdentifier = "com.hublot.cfnotifacation"

func noticationCallBack(center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, name: CFNotificationName?, object: UnsafeRawPointer?, userInfo: CFDictionary?) -> Swift.Void {
	if let name = name {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: notifacationIdentifier),
										object: name.rawValue as String)
	}
}

func listenNotifacation(_ identifier: String) {
	CFNotificationCenterAddObserver(center, nil, noticationCallBack, identifier as CFString, nil, .deliverImmediately)
}

func sendNotifacation(_ identifier: String) {
	CFNotificationCenterPostNotificationWithOptions(center, CFNotificationName.init(identifier as CFString), nil, nil, kCFNotificationDeliverImmediately)
}



public class HTGroupMessage {
	
	let groupIndentifier: String

    public let groupURL: URL
	
    public typealias MessageHandler = (_ identifier: String, _ message: String) -> Void

    var callbackList = [String: [MessageHandler]]()
	
    var sqlite: OpaquePointer?
	
    var lastInsertList = [Int?]()
	
    var defaultMinInsert = -1

    static var messageQueue = DispatchQueue.init(label: "com.hublot.message.messageQueue")
	
    static var callbackQueue = DispatchQueue.init(label: "com.hublot.message.callbackQueue")
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
    public init?(_ groupIndentifier: String) {
		self.groupIndentifier = groupIndentifier
		guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIndentifier) else {
			return nil
		}
		self.groupURL = groupURL
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(notifacationObserver(_:)),
                                               name: NSNotification.Name(rawValue: notifacationIdentifier),
                                               object: nil)
		let path = groupURL.appendingPathComponent("com.hublot.groupmessage.sqlite").path
        let openResult = sqlite3_open(path.cString(using: .utf8), &sqlite)
        guard SQLITE_OK == openResult else {
            return
        }
        let create = """
            create table if not exists message (
                id integer primary key autoincrement,
                identifier text default '' not null,
                message text default '' not null
            )
        """
        sqliteExec(create)
	}
	
	@objc
	func notifacationObserver(_ notifacation: Notification) {
		if let object = notifacation.object, let identifier = object as? String {
			let list = callbackList[identifier] ?? []
			for callback in list {
				callback(identifier, "")
			}
		}
	}

    @discardableResult
    func sqliteExec(_ sql: String) -> Any? {
        guard let sqlite = sqlite else {
            return nil
        }
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(sqlite, sql.cString(using: .utf8), -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer {
            sqlite3_clear_bindings(stmt)
            sqlite3_finalize(stmt)
        }

        let step = sqlite3_step(stmt)
        if step == SQLITE_DONE {
            return SQLITE_OK
        } else if (step == SQLITE_ROW) {
            var result = [[String:Data]]()
            repeat {
                let column = sqlite3_column_count(stmt)
                var dictionary = [String:Data]()
                for i in 0..<column {
                    guard let name = sqlite3_column_name(stmt, i) else {
                        continue
                    }
                    let key = String.init(cString: name, encoding: .utf8) ?? ""
                    let blob = sqlite3_column_text(stmt, i)
                    let count = sqlite3_column_bytes(stmt, i)
                    if let blob = blob {
                        let value = Data.init(bytes: blob, count: Int(count))
                        dictionary[key] = value
                    }
                }
                result.append(dictionary)
            } while (sqlite3_step(stmt) == SQLITE_ROW)
            return result
        }
        return nil
    }
	
    public func post(_ identifier: String, _ message: String = "") {
		type(of: self).messageQueue.async {
			self.syncPost(identifier, message)
		}
	}
	
    public func syncPost(_ identifier: String, _ message: String = "") {
        let insert = "insert into message (identifier, message) values ('\(identifier)', '\(message)')"
        let insertResult = sqliteExec(insert)
        guard SQLITE_OK == insertResult as? Int32 else {
            return
        }
        let fullidentifier = groupIndentifier + identifier
        sendNotifacation(fullidentifier)
	}
	
    public func listen(identifier: String, _ handler: @escaping MessageHandler) {
		let selfclass = type(of: self)
		selfclass.messageQueue.async {
			let index = self.lastInsertList.count
            let result = self.sqliteExec("select max(id) from message where identifier = '\(identifier)'") as? [[String:Data]]
            if let first = result?.first, let count = first["max(id)"], let id = Int.init(String.init(data: count, encoding: .utf8) ?? "") {
				self.lastInsertList.append(id)
			} else {
				self.lastInsertList.append(self.defaultMinInsert)
			}
			let rehandler: MessageHandler = { identifier, _ in
				let last = String(self.lastInsertList[index] ?? self.defaultMinInsert)
                let result = self.sqliteExec("select id, message from message where identifier = '\(identifier)' and id > \(last)") as? [[String: Data]] ?? [[String: Data]]()
				for row in result {
                    guard let count = row["id"], let id = Int.init(String.init(data: count, encoding: .utf8) ?? ""), let messageData = row["message"], let message = String.init(data: messageData, encoding: .utf8)  else {
						continue
					}
					self.lastInsertList[index] = id
					selfclass.callbackQueue.async {
						handler(identifier, message)
					}
				}
			}
            let fullidentifier = self.groupIndentifier + identifier
            if self.callbackList[fullidentifier] == nil {
                self.callbackList[fullidentifier] = [MessageHandler]()
            }
            self.callbackList[fullidentifier]?.append({ _, message in
                rehandler(identifier, message)
            })
            listenNotifacation(fullidentifier)
		}
	}
	
    public func clear() {
        let delete = "delete from message"
        sqlite3_exec(sqlite, delete.cString(using: .utf8), nil, nil, nil)
		self.lastInsertList.removeAll()
	}
	
}
