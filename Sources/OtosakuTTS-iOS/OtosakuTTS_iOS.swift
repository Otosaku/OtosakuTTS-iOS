// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import CoreML
import AVFoundation

public class OtosakuTTS {

    private let fastPitch: MLModel
    private let hifiGAN: MLModel
    private let tokenizer: Tokenizer
    private let audioFormat: AVAudioFormat

    // Model input length constraints
    private let minTokenLength = 2
    private let maxTokenLength = 240
    
    public init(modelDirectoryURL: URL, computeUnits: MLComputeUnits = .all) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        
        do {
            fastPitch = try MLModel(
                contentsOf: modelDirectoryURL.appendingPathComponent("FastPitch.mlmodelc"),
                configuration: configuration
            )
        } catch {
            throw OtosakuTTSError.modelLoadingFailed("FastPitch")
        }
        
        do {
            hifiGAN = try MLModel(
                contentsOf: modelDirectoryURL.appendingPathComponent("HiFiGan.mlmodelc"),
                configuration: configuration
            )
        } catch {
            throw OtosakuTTSError.modelLoadingFailed("HiFiGAN")
        }
        
        do {
            tokenizer = try Tokenizer(
                tokensFile: modelDirectoryURL.appendingPathComponent("tokens.txt"),
                dictFile: modelDirectoryURL.appendingPathComponent("cmudict.json")
            )
        } catch {
            throw OtosakuTTSError.tokenizerInitializationFailed(error.localizedDescription)
        }
        
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 22_050,
            channels: 1,
            interleaved: false
        )!
    }
    
    public func generate(text: String) throws -> AVAudioPCMBuffer {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OtosakuTTSError.emptyInput
        }

        // Segment text by sentence boundaries
        let segments = segmentText(text)

        // If only one segment, process directly
        if segments.count == 1 {
            return try generateSingleSegment(segments[0])
        }

        // Process multiple segments and concatenate
        var buffers: [AVAudioPCMBuffer] = []
        for segment in segments {
            let buffer = try generateSingleSegment(segment)
            buffers.append(buffer)
        }

        return try concatenateBuffers(buffers)
    }

    private func generateSingleSegment(_ text: String) throws -> AVAudioPCMBuffer {
        let phoneIds = tokenizer.encode(text)

        // Check length constraints
        guard phoneIds.count >= minTokenLength else {
            throw OtosakuTTSError.emptyInput
        }

        guard phoneIds.count <= maxTokenLength else {
            throw OtosakuTTSError.inputTooLong(phoneIds.count)
        }

        let phones = try makeMultiArray(from: phoneIds)

        let fastPitchInput = try MLDictionaryFeatureProvider(dictionary: ["x": phones])
        let fastPitchOutput = try fastPitch.prediction(from: fastPitchInput)

        guard let spec = fastPitchOutput.featureValue(for: "spec")?.multiArrayValue else {
            throw OtosakuTTSError.specGenerationFailed
        }

        let hifiGANInput = try MLDictionaryFeatureProvider(dictionary: ["x": spec])
        let hifiGANOutput = try hifiGAN.prediction(from: hifiGANInput)

        guard let waveform = hifiGANOutput.featureValue(for: "waveform")?.multiArrayValue else {
            throw OtosakuTTSError.waveformGenerationFailed
        }

        return try createAudioBuffer(from: waveform)
    }
    
    private func segmentText(_ text: String) -> [String] {
        // Split by sentence boundaries (period, question mark, exclamation mark)
        let sentencePattern = #"[^.!?。!?]+[.!?。!?]+"#
        let regex = try! NSRegularExpression(pattern: sentencePattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        var segments: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    // Check if this sentence fits within token limits
                    let phoneIds = tokenizer.encode(sentence)
                    if phoneIds.count <= maxTokenLength {
                        segments.append(sentence)
                    } else {
                        // If a single sentence is too long, try splitting by commas
                        let subSegments = segmentByCommas(sentence)
                        segments.append(contentsOf: subSegments)
                    }
                }
            }
        }

        // Handle any remaining text without punctuation
        if segments.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let phoneIds = tokenizer.encode(trimmed)
                if phoneIds.count <= maxTokenLength {
                    segments.append(trimmed)
                } else {
                    // Try splitting by commas
                    segments = segmentByCommas(trimmed)
                }
            }
        }

        return segments.isEmpty ? [text] : segments
    }

    private func segmentByCommas(_ text: String) -> [String] {
        let parts = text.components(separatedBy: CharacterSet(charactersIn: ",，、"))
        var segments: [String] = []
        var currentSegment = ""

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let testSegment = currentSegment.isEmpty ? trimmed : currentSegment + ", " + trimmed
            let phoneIds = tokenizer.encode(testSegment)

            if phoneIds.count <= maxTokenLength {
                currentSegment = testSegment
            } else {
                // If current segment has content, save it
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }

                // Check if the trimmed part itself is too long
                let trimmedPhoneIds = tokenizer.encode(trimmed)
                if trimmedPhoneIds.count > maxTokenLength {
                    // Last resort: split by words
                    let wordSegments = segmentByWords(trimmed)
                    segments.append(contentsOf: wordSegments)
                    currentSegment = ""
                } else {
                    currentSegment = trimmed
                }
            }
        }

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        return segments
    }

    private func segmentByWords(_ text: String) -> [String] {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var segments: [String] = []
        var currentSegment = ""

        for word in words {
            let testSegment = currentSegment.isEmpty ? word : currentSegment + " " + word
            let phoneIds = tokenizer.encode(testSegment)

            if phoneIds.count <= maxTokenLength {
                currentSegment = testSegment
            } else {
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }

                // If a single word is too long, we have to accept it and let it fail
                // This is an extreme edge case (a word with 240+ phonemes)
                currentSegment = word
            }
        }

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        return segments.isEmpty ? [text] : segments
    }

    private func makeMultiArray(from ints: [Int]) throws -> MLMultiArray {
        let arr = try MLMultiArray(shape: [1, NSNumber(value: ints.count)], dataType: .int32)
        for (i, v) in ints.enumerated() { 
            arr[i] = NSNumber(value: Int32(v)) 
        }
        return arr
    }
    
    private func concatenateBuffers(_ buffers: [AVAudioPCMBuffer]) throws -> AVAudioPCMBuffer {
        guard !buffers.isEmpty else {
            throw OtosakuTTSError.audioBufferCreationFailed
        }

        // Calculate total length with silence padding between segments
        let silenceSamples = Int(audioFormat.sampleRate * 0.3) // 300ms silence between sentences
        let totalLength = buffers.reduce(0) { $0 + Int($1.frameLength) } + (buffers.count - 1) * silenceSamples

        guard let concatenatedBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(totalLength)
        ) else {
            throw OtosakuTTSError.audioBufferCreationFailed
        }

        concatenatedBuffer.frameLength = AVAudioFrameCount(totalLength)

        guard let outputData = concatenatedBuffer.floatChannelData?[0] else {
            throw OtosakuTTSError.audioBufferCreationFailed
        }

        var currentPosition = 0

        for (index, buffer) in buffers.enumerated() {
            guard let inputData = buffer.floatChannelData?[0] else {
                throw OtosakuTTSError.audioBufferCreationFailed
            }

            let frameCount = Int(buffer.frameLength)

            // Copy audio data
            memcpy(outputData.advanced(by: currentPosition), inputData, frameCount * MemoryLayout<Float>.size)
            currentPosition += frameCount

            // Add silence between segments (except after the last segment)
            if index < buffers.count - 1 {
                // Silence is already zero-initialized, just skip ahead
                currentPosition += silenceSamples
            }
        }

        return concatenatedBuffer
    }

    private func createAudioBuffer(from array: MLMultiArray) throws -> AVAudioPCMBuffer {
        let length = array.count
        var floats = [Float](repeating: 0, count: length)
        for i in 0..<length {
            floats[i] = array[i].floatValue
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(length)
        ) else {
            throw OtosakuTTSError.audioBufferCreationFailed
        }

        buffer.frameLength = buffer.frameCapacity
        buffer.floatChannelData!.pointee.update(from: &floats, count: length)

        return buffer
    }
}
