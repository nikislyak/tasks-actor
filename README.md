# ``TasksActor``

A simple tool that helps avoid async work duplications and swift actor reentrancy 

## Example of usage

Here is some service protocol

```swift
protocol ServiceProtocol {
    func loadData() async throws -> Int
}
```
And a class implementing the protocol. Such implementation generates a new `Int` value each time

```swift
extension Int {
    static func randomAsync() async throws -> Int {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        return .random(in: 0 ..< 100)
    }
}

final class Service: ServiceProtocol {
    private actor Cache {
        var value: Int?

        func set(value: Int) {
            self.value = value
        }
    }

    private let cache = Cache()

    func loadData() async throws -> Int {
        let value = try await Int.randomAsync()
        await cache.set(value: value)
        return value
    }
}
```
But if you need to generate it only once you will face an actor reentrancy problem
```swift
func loadData() async throws -> Int {
    if let value = await cache.value {
        return value
    }
    let value = try await Int.randomAsync()
    await cache.set(value: value) // it possible that two different tasks execute this line twice
    return value
}
```
`TasksActor` helps to solve this problem
```swift
final class AwesomeService: ServiceProtocol {
    private actor Cache {
        var value: Int?

        func set(value: Int) {
            self.value = value
        }
    }

    private let cache = Cache()
    private let tasksActor = TasksActor<String, Int>()

    func loadData() async throws -> Int {
        try await tasksActor.launchIfNeeded(byKey: "SomeKey") { [cache] in
            if let value = await cache.value {
                return value
            }
            let value = try await Int.randomAsync()
            await cache.set(value: value) // no reentrancy
            return value
        }
    }
}
```
