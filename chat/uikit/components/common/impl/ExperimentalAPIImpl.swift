import Foundation

enum ExperimentalAPIImpl {
    private static let errorUnknown: Int32 = -1


    static func callExperimentalAPI(api: String,
                                    params: String,
                                    onSuccess: @escaping (String) -> Void,
                                    onFailure: @escaping (Int32, String) -> Void) {
        let invoked = ExperimentalAPICall.invoke(withApi: api, params: params, success: { result in
            DispatchQueue.main.async { onSuccess(result?.description ?? "") }
        }, failure: { code, desc in
            DispatchQueue.main.async { onFailure(code, desc ?? "") }
        })
        if !invoked {
            onFailure(errorUnknown, "V2TIMManager callExperimentalAPI unavailable")
        }
    }


    static func uploadAudioFile(filePath: String,
                                onSuccess: @escaping (String) -> Void,
                                onFailure: @escaping (Int32, String) -> Void) {
        let params = jsonString(["filePath": filePath, "fileType": 3]) ?? ""
        callExperimentalAPI(api: "uploadFile", params: params, onSuccess: { result in
            if result.isEmpty {
                onFailure(errorUnknown, "upload url is empty")
            } else {
                onSuccess(result)
            }
        }, onFailure: onFailure)
    }


    static func convertVoiceToText(url: String,
                                   language: String = "",
                                   onSuccess: @escaping (String) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        let params = jsonString(["url": url, "language": language]) ?? ""
        callExperimentalAPI(api: "convertVoiceToText", params: params, onSuccess: { result in
            let text = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                onFailure(errorUnknown, "voice to text result is empty")
            } else {
                onSuccess(text)
            }
        }, onFailure: onFailure)
    }

    static func convertLocalAudioToText(filePath: String,
                                        onSuccess: @escaping (String) -> Void,
                                        onFailure: @escaping (Int32, String) -> Void) {
        uploadAudioFile(filePath: filePath, onSuccess: { url in
            convertVoiceToText(url: url, language: "", onSuccess: onSuccess, onFailure: onFailure)
        }, onFailure: onFailure)
    }


    static func translateSingleText(text: String,
                                    targetLanguage: String,
                                    sourceLanguage: String = "",
                                    onSuccess: @escaping (String) -> Void,
                                    onFailure: @escaping (Int32, String) -> Void) {
        guard let manager = VideoRecorderReflectUtil.invokeStaticMethod("V2TIMManager", methodName: "sharedInstance", withArguments: []) else {
            onFailure(errorUnknown, "V2TIMManager unavailable")
            return
        }
        typealias CallbackBlock = @convention(block) (Int32, AnyObject?, AnyObject?) -> Void
        let callback: CallbackBlock = { code, desc, result in
            DispatchQueue.main.async {
                if code != 0 {
                    onFailure(code, (desc as? String) ?? "")
                    return
                }
                let map = result as? [String: String]
                guard let translated = map?[text], !translated.isEmpty else {
                    onFailure(errorUnknown, "translation result is empty")
                    return
                }
                onSuccess(translated)
            }
        }
        // SDK selector 的尾部参数为 completion，使用错误名称将无法收到回调。
        VideoRecorderReflectUtil.invokeMethod(
            manager,
            methodName: "translateText:sourceLanguage:targetLanguage:completion:",
            withArguments: [[text], sourceLanguage.isEmpty ? NSNull() : sourceLanguage, targetLanguage, callback]
        )
    }


    static func convertTextToVoice(text: String,
                                   voiceId: String = "",
                                   audioFormat: String = "wav",
                                   language: String = "",
                                   onSuccess: @escaping (String) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        var dict: [String: Any] = ["text": text, "audioFormat": audioFormat, "language": language]
        if !voiceId.isEmpty { dict["voiceId"] = voiceId }
        let params = jsonString(dict) ?? ""
        callExperimentalAPI(api: "convertTextToVoice", params: params, onSuccess: { result in
            if let data = result.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let url = json["audioUrl"] as? String, !url.isEmpty
            {
                onSuccess(url)
            } else {
                onFailure(errorUnknown, "tts audio url is empty")
            }
        }, onFailure: onFailure)
    }


    static func voiceClone(filePath: String,
                           voiceName: String,
                           promptText: String = "",
                           language: String = "",
                           onSuccess: @escaping (String) -> Void,
                           onFailure: @escaping (Int32, String) -> Void) {
        uploadAudioFile(filePath: filePath, onSuccess: { audioUrl in
            let params = jsonString(["voiceName": voiceName, "audioUrl": audioUrl, "promptText": promptText, "language": language]) ?? ""
            callExperimentalAPI(api: "voiceClone", params: params, onSuccess: { result in
                if let voiceId = parseVoiceId(result), !voiceId.isEmpty {
                    onSuccess(voiceId)
                } else {
                    onFailure(errorUnknown, "voice clone id is empty")
                }
            }, onFailure: onFailure)
        }, onFailure: onFailure)
    }

    static func getCustomVoiceList(onSuccess: @escaping ([CustomVoiceItem]) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        callExperimentalAPI(api: "getCustomVoiceList", params: "{}", onSuccess: { result in
            onSuccess(parseVoiceList(result))
        }, onFailure: onFailure)
    }

    static func deleteCustomVoice(voiceId: String,
                                  onSuccess: @escaping () -> Void,
                                  onFailure: @escaping (Int32, String) -> Void) {
        let params = jsonString(["voiceId": voiceId]) ?? ""
        callExperimentalAPI(api: "deleteCustomVoice", params: params, onSuccess: { _ in
            onSuccess()
        }, onFailure: onFailure)
    }

    private static func parseVoiceId(_ result: String) -> String? {
        guard !result.isEmpty,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["voiceId"] as? String, !id.isEmpty else { return nil }
        return id
    }

    private static func parseVoiceList(_ result: String) -> [CustomVoiceItem] {
        guard !result.isEmpty,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let array = json["voiceList"] as? [[String: Any]] else { return [] }
        var list: [CustomVoiceItem] = []
        for item in array {
            guard let id = item["voiceId"] as? String, !id.isEmpty else { continue }
            let name = item["voiceName"] as? String ?? ""
            list.append(CustomVoiceItem(voiceId: id, name: name, isDefault: false))
        }
        return list
    }


    static func sdkVersion() -> String {
        guard let manager = VideoRecorderReflectUtil.invokeStaticMethod("V2TIMManager", methodName: "sharedInstance", withArguments: []) else { return "" }
        let version = VideoRecorderReflectUtil.invokeMethod(manager, methodName: "getVersion", withArguments: [])
        return (version as? String) ?? ""
    }


    private static func jsonString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}
