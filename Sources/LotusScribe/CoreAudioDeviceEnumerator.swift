import CoreAudio
import Foundation
import os

/// EDGE, human-verified (Phase 11A, D109): the concrete
/// `AudioInputDeviceEnumerating` doing the Core Audio property reads
/// (kAudioHardwarePropertyDevices, per-device UID / name / input channel
/// count, and the default input device). No pure logic — it produces
/// `[AudioInputDevice]` values the pure layer (`AudioInputDevice.swift`)
/// shapes. See docs/phase-11-spec.md §11A.
///
/// Degrades to `[]`/nil on any Core Audio error and never throws — it may run
/// before Microphone TCC is granted (constraint D88); a hard failure here must
/// not break the app.
final class CoreAudioDeviceEnumerator: AudioInputDeviceEnumerating {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "CoreAudioDeviceEnumerator")

    /// Input-capable devices (channel count > 0) — includes virtual mics,
    /// excludes output-only devices (handoff §3). Unordered; the pure menu
    /// model sorts.
    func inputDevices() -> [AudioInputDevice] {
        allDeviceIDs().compactMap { id in
            guard inputChannelCount(of: id) > 0 else { return nil }
            guard let uid = uid(of: id), let name = name(of: id) else { return nil }
            return AudioInputDevice(uid: uid, name: name, id: id)
        }
    }

    /// The device macOS currently uses as the default input, mapped to its
    /// enumerated (input-capable) entry, or nil.
    func defaultInputDevice() -> AudioInputDevice? {
        var address = Self.address(kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return inputDevices().first { $0.id == deviceID }
    }

    // MARK: - Core Audio reads

    private func allDeviceIDs() -> [AudioDeviceID] {
        var address = Self.address(kAudioHardwarePropertyDevices)
        var dataSize: UInt32 = 0
        guard
            AudioObjectGetPropertyDataSize(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr
        else {
            Self.logger.error("device list size read failed; degrading to empty")
            return []
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids) == noErr
        else {
            Self.logger.error("device list read failed; degrading to empty")
            return []
        }
        return ids
    }

    private func uid(of id: AudioDeviceID) -> String? {
        cfStringProperty(id, kAudioDevicePropertyDeviceUID, scope: kAudioObjectPropertyScopeGlobal)
    }

    /// Device name. Engineer-confirmed at compile: `kAudioObjectPropertyName`
    /// (spec's first candidate) compiles and returns a usable human name; the
    /// `kAudioDevicePropertyDeviceNameCFString` alternative was not needed.
    private func name(of id: AudioDeviceID) -> String? {
        cfStringProperty(id, kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)
    }

    /// Sum of input-scope channels via kAudioDevicePropertyStreamConfiguration;
    /// 0 (excluded) for output-only devices.
    private func inputChannelCount(of id: AudioDeviceID) -> Int {
        var address = Self.address(
            kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else {
            return 0
        }
        let bufferListPtr = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferListPtr.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, bufferListPtr) == noErr else {
            return 0
        }
        let list = UnsafeMutableAudioBufferListPointer(
            bufferListPtr.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    /// Read a CFString-typed device property; nil on any Core Audio error.
    private func cfStringProperty(
        _ id: AudioDeviceID, _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> String? {
        var address = Self.address(selector, scope: scope)
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        guard status == noErr, let value else { return nil }
        return value as String
    }

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
