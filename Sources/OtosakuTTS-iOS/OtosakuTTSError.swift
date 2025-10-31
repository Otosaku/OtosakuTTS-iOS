//
//  OtosakuTTSError.swift
//  OtosakuTTS-iOS
//

import Foundation

public enum OtosakuTTSError: LocalizedError {
    case modelLoadingFailed(String)
    case tokenizerInitializationFailed(String)
    case specGenerationFailed
    case waveformGenerationFailed
    case audioBufferCreationFailed
    case invalidTokensFile
    case invalidDictionaryFile
    case emptyInput
    case inputTooLong(Int)

    public var errorDescription: String? {
        switch self {
        case .modelLoadingFailed(let model):
            return "Failed to load \(model) model"
        case .tokenizerInitializationFailed(let reason):
            return "Failed to initialize tokenizer: \(reason)"
        case .specGenerationFailed:
            return "Failed to generate spectrogram from FastPitch"
        case .waveformGenerationFailed:
            return "Failed to generate waveform from HiFiGAN"
        case .audioBufferCreationFailed:
            return "Failed to create audio buffer"
        case .invalidTokensFile:
            return "Invalid or missing tokens file"
        case .invalidDictionaryFile:
            return "Invalid or missing dictionary file"
        case .emptyInput:
            return "Input text is empty"
        case .inputTooLong(let length):
            return "Input text is too long (\(length) tokens). Single sentence must be within 240 tokens."
        }
    }
}