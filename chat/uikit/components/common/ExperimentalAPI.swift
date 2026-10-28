import Foundation

public enum ExperimentalAPI {
    static func callExperimentalAPI(api: String,
                                    params: String,
                                    onSuccess: @escaping (String) -> Void,
                                    onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.callExperimentalAPI(api: api, params: params, onSuccess: onSuccess, onFailure: onFailure)
    }

    static func uploadAudioFile(filePath: String,
                                onSuccess: @escaping (String) -> Void,
                                onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.uploadAudioFile(filePath: filePath, onSuccess: onSuccess, onFailure: onFailure)
    }

    static func convertVoiceToText(url: String,
                                   language: String = "",
                                   onSuccess: @escaping (String) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.convertVoiceToText(url: url, language: language, onSuccess: onSuccess, onFailure: onFailure)
    }

    static func convertLocalAudioToText(filePath: String,
                                        onSuccess: @escaping (String) -> Void,
                                        onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.convertLocalAudioToText(filePath: filePath, onSuccess: onSuccess, onFailure: onFailure)
    }

    static func translateSingleText(text: String,
                                    targetLanguage: String,
                                    sourceLanguage: String = "",
                                    onSuccess: @escaping (String) -> Void,
                                    onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.translateSingleText(text: text, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage, onSuccess: onSuccess, onFailure: onFailure)
    }

    static func convertTextToVoice(text: String,
                                   voiceId: String = "",
                                   audioFormat: String = "wav",
                                   language: String = "",
                                   onSuccess: @escaping (String) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.convertTextToVoice(text: text, voiceId: voiceId, audioFormat: audioFormat, language: language, onSuccess: onSuccess, onFailure: onFailure)
    }

    public static func voiceClone(filePath: String,
                           voiceName: String,
                           promptText: String = "",
                           language: String = "",
                           onSuccess: @escaping (String) -> Void,
                           onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.voiceClone(filePath: filePath, voiceName: voiceName, promptText: promptText, language: language, onSuccess: onSuccess, onFailure: onFailure)
    }

    public static func getCustomVoiceList(onSuccess: @escaping ([CustomVoiceItem]) -> Void,
                                   onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.getCustomVoiceList(onSuccess: onSuccess, onFailure: onFailure)
    }

    public static func deleteCustomVoice(voiceId: String,
                                  onSuccess: @escaping () -> Void,
                                  onFailure: @escaping (Int32, String) -> Void) {
        ExperimentalAPIImpl.deleteCustomVoice(voiceId: voiceId, onSuccess: onSuccess, onFailure: onFailure)
    }

    public static func sdkVersion() -> String {
        ExperimentalAPIImpl.sdkVersion()
    }
}
