import ServiceManagement

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

enum LoginItemSettings {
    static func isRegistered(_ status: SMAppService.Status) -> Bool {
        status == .enabled || status == .requiresApproval
    }

    static func toggle(_ service: LoginItemService) throws {
        if isRegistered(service.status) { try service.unregister() }
        else { try service.register() }
    }
}
