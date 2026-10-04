import Foundation
import Testing
@testable import CheckLine

struct VoiceCaptureSessionTests {
    @Test("取消语音恢复录音前输入，迟到转写不能重新写入")
    func cancelRestoresOriginalText() {
        var capture = VoiceCaptureSession()
        let original = "已有草稿  \n"
        let id = capture.begin(initialText: original)
        let beganListening = capture.beginListening(id: id)
        #expect(beganListening)
        let receivedText = capture.receive("午餐三十五元", id: id)
        #expect(receivedText)
        #expect(capture.draftText == original + "午餐三十五元")
        let cancelled = capture.cancel()
        #expect(cancelled)
        #expect(capture.draftText == original)
        #expect(capture.phase == .idle && !capture.isActive)
        let receivedAfterCancel = capture.receive("午餐三十六元", id: id)
        #expect(!receivedAfterCancel)
        let finishedAfterCancel = capture.finish(id: id)
        #expect(!finishedAfterCancel)
        #expect(capture.draftText == original)
    }

    @Test("中间识别结果替换本轮转写，不重复追加已有草稿")
    func partialResultsReplaceOnlyCurrentUtterance() {
        var capture = VoiceCaptureSession()
        let id = capture.begin(initialText: "今天")
        capture.beginListening(id: id)
        capture.receive("午餐", id: id)
        capture.receive("午餐三十五元", id: id)
        #expect(capture.draftText == "今天 午餐三十五元")
        let receivedDuplicate = capture.receive("  午餐三十五元  ", id: id)
        #expect(!receivedDuplicate)
        let receivedBlank = capture.receive("\n ", id: id)
        #expect(!receivedBlank)
        #expect(capture.draftText == "今天 午餐三十五元")
    }

    @Test("重新开始后旧授权和旧识别回调不能启动或覆盖新录音")
    func restartInvalidatesEarlierPermissionAndResults() {
        var capture = VoiceCaptureSession()
        let oldID = capture.begin(initialText: "旧草稿")
        capture.cancel()
        let currentID = capture.begin(initialText: "新草稿")
        let oldSessionStarted = capture.beginListening(id: oldID)
        #expect(!oldSessionStarted)
        let oldSessionFailed = capture.fail(.microphoneDenied, id: oldID)
        #expect(!oldSessionFailed)
        let oldSessionReceivedText = capture.receive("过期转写", id: oldID)
        #expect(!oldSessionReceivedText)
        #expect(capture.phase == .requestingPermission)
        let currentSessionStarted = capture.beginListening(id: currentID)
        #expect(currentSessionStarted)
        capture.receive("咖啡二十元", id: currentID)
        #expect(capture.draftText == "新草稿 咖啡二十元")
    }

    @Test("结束允许最后一次修订，完成后不再被旧结果或取消改写")
    func finishRetainsFinalRevision() {
        var capture = VoiceCaptureSession()
        let id = capture.begin(initialText: "")
        capture.beginListening(id: id)
        capture.receive("午餐三十", id: id)
        let beganFinishing = capture.beginFinishing(id: id)
        #expect(beganFinishing)
        let receivedFinalText = capture.receive("午餐三十五元", id: id)
        #expect(receivedFinalText)
        let finished = capture.finish(id: id)
        #expect(finished)
        #expect(capture.phase == .finished && !capture.isActive)
        let cancelledAfterFinish = capture.cancel()
        #expect(!cancelledAfterFinish)
        let receivedAfterFinish = capture.receive("过期结果", id: id)
        #expect(!receivedAfterFinish)
        #expect(capture.draftText == "午餐三十五元")
    }

    @Test("电话或后台中断保留已有转写，识别不会自动恢复")
    func interruptionRetainsText() {
        var capture = VoiceCaptureSession()
        let id = capture.begin(initialText: "原文")
        capture.beginListening(id: id)
        capture.receive("追加内容", id: id)
        let interrupted = capture.fail(.interrupted, id: id)
        #expect(interrupted)
        #expect(capture.draftText == "原文 追加内容")
        #expect(capture.phase == .failed(.interrupted) && !capture.isActive)
        let restartedAfterInterruption = capture.beginListening(id: id)
        #expect(!restartedAfterInterruption)
        let receivedAfterInterruption = capture.receive("中断后结果", id: id)
        #expect(!receivedAfterInterruption)
    }

    @Test("无声结束明确失败，已有文字不能被误报为语音成功")
    func noSpeechPreservesDraftWithoutSuccess() {
        var capture = VoiceCaptureSession()
        let id = capture.begin(initialText: "仍可编辑的文字")
        capture.beginListening(id: id)
        capture.beginFinishing(id: id)
        capture.finish(id: id)
        #expect(capture.phase == .failed(.noSpeech))
        #expect(capture.draftText == "仍可编辑的文字")
        #expect(!capture.isActive)
    }

    @Test("授权拒绝终止会话并保留输入，只为可修改的拒绝提供设置入口")
    func deniedPermissionPreservesDraft() {
        var capture = VoiceCaptureSession()
        let id = capture.begin(initialText: "用户输入")
        capture.fail(.microphoneDenied, id: id)
        #expect(capture.draftText == "用户输入")
        let startedWithoutPermission = capture.beginListening(id: id)
        #expect(!startedWithoutPermission)
        let receivedWithoutPermission = capture.receive("未授权内容", id: id)
        #expect(!receivedWithoutPermission)
        #expect(VoiceCaptureIssue.microphoneDenied.canOpenSettings)
        #expect(VoiceCaptureIssue.speechDenied.canOpenSettings)
        #expect(!VoiceCaptureIssue.onDeviceUnavailable.canOpenSettings)
        #expect(!VoiceCaptureIssue.speechRestricted.canOpenSettings)
    }
}
