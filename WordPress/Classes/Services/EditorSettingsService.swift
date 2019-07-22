import Foundation

@objc enum EditorSettingsServiceError: Int, Swift.Error {
    case mobileEditorNotSet
}

@objc class EditorSettingsService: LocalCoreDataService {
    @objc func syncEditorSettings(for blog: Blog, success: @escaping () -> Void, failure: @escaping (Swift.Error) -> Void) {
        guard let api = blog.wordPressComRestApi(), let siteID = blog.dotComID?.intValue else {
            let error = NSError(domain: "EditorSettingsService", code: 0, userInfo: [NSDebugDescriptionErrorKey: "Api or dotCom Site ID not found"])
            failure(error)
            return
        }

        let service = EditorServiceRemote(wordPressComRestApi: api)
        service.getEditorSettings(siteID, success: { (settings) in
            do {
                try self.saveRemoteEditorSettings(settings, on: blog)
            } catch {
                failure(error)
            }
            ContextManager.sharedInstance().save(self.managedObjectContext)
            success()
        }, failure: failure)
    }

    private func saveRemoteEditorSettings(_ settings: EditorSettings, on blog: Blog) throws {
        guard settings.mobile != .notSet else {
            throw EditorSettingsServiceError.mobileEditorNotSet
        }
        blog.mobileEditor = settings.mobile.rawValue
        blog.webEditor = settings.web.rawValue
    }

    func postEditorSetting(_ newEditor: MobileEditor, for blog: Blog, success: @escaping () -> Void, failure: @escaping (Swift.Error) -> Void) {
        guard
            let remoteEditor = EditorSettings.Mobile(rawValue: newEditor.rawValue),
            let api = blog.wordPressComRestApi(),
            let siteID = blog.dotComID?.intValue
        else {
            let error = NSError(domain: "EditorSettingsService", code: 0, userInfo: [NSDebugDescriptionErrorKey: "Api or dotCom Site ID not found"])
            failure(error)
            return
        }
        let oldValue = blog.mobileEditor
        blog.mobileEditor = newEditor.rawValue

        let service = EditorServiceRemote(wordPressComRestApi: api)
        service.postDesignateMobileEditor(siteID, editor: remoteEditor, success: { _ in
            ContextManager.sharedInstance().save(self.managedObjectContext)
            success()
        }) { (error) in
            blog.mobileEditor = oldValue
            failure(error)
        }
    }
}
