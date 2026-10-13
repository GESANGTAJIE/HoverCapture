import ServiceManagement

private final class FakeLoginItem: LoginItemService {
    let status: SMAppService.Status
    var registered = 0
    var unregistered = 0
    var failure: Error?
    init(_ status: SMAppService.Status) { self.status = status }
    func register() throws {
        registered += 1
        if let failure { throw failure }
    }
    func unregister() throws {
        unregistered += 1
        if let failure { throw failure }
    }
}

private enum TestFailure: Error { case failed(String), expected }

@main
struct LoginItemTests {
    static func main() throws {
        var checks = 0
        func expect(_ name: String, _ condition: Bool) throws {
            guard condition else { throw TestFailure.failed(name) }
            checks += 1
        }
        for state in [SMAppService.Status.enabled, .requiresApproval] {
            let service = FakeLoginItem(state)
            try expect("registered state is checked: \(state)", LoginItemSettings.isRegistered(state))
            try LoginItemSettings.toggle(service)
            try expect("registered state can be canceled: \(state)", service.unregistered == 1 && service.registered == 0)
            service.failure = TestFailure.expected
            do {
                try LoginItemSettings.toggle(service)
                throw TestFailure.failed("unregister error was swallowed")
            } catch TestFailure.expected { checks += 1 }
        }
        for state in [SMAppService.Status.notRegistered, .notFound] {
            let service = FakeLoginItem(state)
            try expect("unregistered state is unchecked: \(state)", !LoginItemSettings.isRegistered(state))
            try LoginItemSettings.toggle(service)
            try expect("new registration: \(state)", service.registered == 1 && service.unregistered == 0)
        }
        let failing = FakeLoginItem(.notRegistered)
        failing.failure = TestFailure.expected
        do {
            try LoginItemSettings.toggle(failing)
            throw TestFailure.failed("register error was swallowed")
        } catch TestFailure.expected { checks += 1 }
        print("Login item tests: \(checks) passed, 0 failed")
    }
}
