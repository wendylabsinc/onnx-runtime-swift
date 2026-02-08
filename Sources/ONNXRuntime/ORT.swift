#if ORT_CUDA
@_exported import ONNXRuntimeCUDABinary
#elseif ORT_ROCM
@_exported import ONNXRuntimeROCmBinary
#else
@_exported import ONNXRuntimeCPUBinary
#endif
import Foundation

public enum ORT {
    public static let apiVersion: UInt32 = ORT_API_VERSION

    public static var versionString: String {
        guard let base = OrtGetApiBase() else { return "unknown" }
        guard let getVersion = base.pointee.GetVersionString else { return "unknown" }
        return String(cString: getVersion())
    }
}

public enum ORTError: Error, CustomStringConvertible {
    case ort(code: OrtErrorCode, message: String)
    case invalidArgument(String)
    case unsupported(String)

    public var description: String {
        switch self {
        case let .ort(code, message):
            return "ONNX Runtime error (\(code)): \(message)"
        case let .invalidArgument(message):
            return "Invalid argument: \(message)"
        case let .unsupported(message):
            return "Unsupported: \(message)"
        }
    }
}

enum ORTAPI {
    static let api: UnsafePointer<OrtApi> = {
        guard let base = OrtGetApiBase() else {
            fatalError("OrtGetApiBase returned nil")
        }
        guard let getApi = base.pointee.GetApi else {
            fatalError("OrtApiBase.GetApi is nil")
        }
        guard let api = getApi(ORT_API_VERSION) else {
            fatalError("OrtApi version \(ORT_API_VERSION) is not supported by this runtime")
        }
        return api
    }()

    static func check(_ status: UnsafeMutablePointer<OrtStatus>?) throws {
        guard let status = status else { return }
        let message = String(cString: api.pointee.GetErrorMessage(status))
        let code = api.pointee.GetErrorCode(status)
        api.pointee.ReleaseStatus(status)
        throw ORTError.ort(code: code, message: message)
    }

    static func defaultAllocator() throws -> UnsafeMutablePointer<OrtAllocator> {
        var allocator: UnsafeMutablePointer<OrtAllocator>?
        try check(api.pointee.GetAllocatorWithDefaultOptions(&allocator))
        guard let allocator else {
            throw ORTError.invalidArgument("Default allocator not available")
        }
        return allocator
    }

    private static var cachedCpuMemoryInfo: UnsafePointer<OrtMemoryInfo>?

    static func cpuMemoryInfo() throws -> UnsafePointer<OrtMemoryInfo> {
        if let cachedCpuMemoryInfo {
            return cachedCpuMemoryInfo
        }
        var info: UnsafeMutablePointer<OrtMemoryInfo>?
        try check(api.pointee.CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &info))
        guard let info else {
            throw ORTError.invalidArgument("Failed to create CPU memory info")
        }
        let immutable = UnsafePointer(info)
        cachedCpuMemoryInfo = immutable
        return immutable
    }
}

public final class ORTEnvironment {
    let handle: UnsafeMutablePointer<OrtEnv>

    public init(loggingLevel: OrtLoggingLevel = ORT_LOGGING_LEVEL_WARNING, logId: String = "onnxruntime") throws {
        var env: UnsafeMutablePointer<OrtEnv>?
        try logId.withCString { cLogId in
            try ORTAPI.check(ORTAPI.api.pointee.CreateEnv(loggingLevel, cLogId, &env))
        }
        guard let env else {
            throw ORTError.invalidArgument("Failed to create OrtEnv")
        }
        self.handle = env
    }

    deinit {
        ORTAPI.api.pointee.ReleaseEnv(handle)
    }
}

public final class ORTSessionOptions {
    let handle: UnsafeMutablePointer<OrtSessionOptions>

    public init() throws {
        var options: UnsafeMutablePointer<OrtSessionOptions>?
        try ORTAPI.check(ORTAPI.api.pointee.CreateSessionOptions(&options))
        guard let options else {
            throw ORTError.invalidArgument("Failed to create OrtSessionOptions")
        }
        self.handle = options
    }

    deinit {
        ORTAPI.api.pointee.ReleaseSessionOptions(handle)
    }

    public func setIntraOpNumThreads(_ count: Int32) throws {
        try ORTAPI.check(ORTAPI.api.pointee.SetIntraOpNumThreads(handle, count))
    }

    public func setInterOpNumThreads(_ count: Int32) throws {
        try ORTAPI.check(ORTAPI.api.pointee.SetInterOpNumThreads(handle, count))
    }

    public func setGraphOptimizationLevel(_ level: OptimizationLevel) throws {
        try ORTAPI.check(ORTAPI.api.pointee.SetSessionGraphOptimizationLevel(handle, level.rawValue))
    }

    public func appendCUDA() throws {
        var options: UnsafeMutablePointer<OrtCUDAProviderOptionsV2>?
        try ORTAPI.check(ORTAPI.api.pointee.CreateCUDAProviderOptions(&options))
        guard let options else {
            throw ORTError.invalidArgument("Failed to create CUDA provider options")
        }
        defer { ORTAPI.api.pointee.ReleaseCUDAProviderOptions(options) }
        try ORTAPI.check(ORTAPI.api.pointee.SessionOptionsAppendExecutionProvider_CUDA_V2(handle, options))
    }

    public func appendMIGraphX(
        deviceId: Int32 = 0,
        enableFP16: Bool = false,
        enableInt8: Bool = false,
        useNativeCalibrationTable: Bool = false,
        saveCompiledModel: Bool = false,
        saveModelPath: String? = nil,
        loadCompiledModel: Bool = false,
        loadModelPath: String? = nil,
        exhaustiveTune: Bool = false
    ) throws {
        var options = OrtMIGraphXProviderOptions(
            device_id: deviceId,
            migraphx_fp16_enable: enableFP16 ? 1 : 0,
            migraphx_int8_enable: enableInt8 ? 1 : 0,
            migraphx_use_native_calibration_table: useNativeCalibrationTable ? 1 : 0,
            migraphx_int8_calibration_table_name: nil,
            migraphx_save_compiled_model: saveCompiledModel ? 1 : 0,
            migraphx_save_model_path: nil,
            migraphx_load_compiled_model: loadCompiledModel ? 1 : 0,
            migraphx_load_model_path: nil,
            migraphx_exhaustive_tune: exhaustiveTune
        )

        if saveModelPath != nil && loadModelPath != nil {
            throw ORTError.invalidArgument("Provide either saveModelPath or loadModelPath, not both.")
        }

        if let saveModelPath {
            try saveModelPath.withCString { cstr in
                options.migraphx_save_model_path = cstr
                try ORTAPI.check(ORTAPI.api.pointee.SessionOptionsAppendExecutionProvider_MIGraphX(handle, &options))
            }
        } else if let loadModelPath {
            try loadModelPath.withCString { cstr in
                options.migraphx_load_model_path = cstr
                try ORTAPI.check(ORTAPI.api.pointee.SessionOptionsAppendExecutionProvider_MIGraphX(handle, &options))
            }
        } else {
            try ORTAPI.check(ORTAPI.api.pointee.SessionOptionsAppendExecutionProvider_MIGraphX(handle, &options))
        }
    }

    public enum OptimizationLevel {
        case disable
        case basic
        case extended
        case all

        var rawValue: GraphOptimizationLevel {
            switch self {
            case .disable:
                return ORT_DISABLE_ALL
            case .basic:
                return ORT_ENABLE_BASIC
            case .extended:
                return ORT_ENABLE_EXTENDED
            case .all:
                return ORT_ENABLE_ALL
            }
        }
    }
}

public final class ORTSession {
    let handle: UnsafeMutablePointer<OrtSession>
    let environment: ORTEnvironment

    public init(environment: ORTEnvironment, modelPath: String, options: ORTSessionOptions? = nil) throws {
        var session: UnsafeMutablePointer<OrtSession>?
        try withOrtPath(modelPath) { cPath in
            try ORTAPI.check(ORTAPI.api.pointee.CreateSession(environment.handle, cPath, options?.handle, &session))
        }
        guard let session else {
            throw ORTError.invalidArgument("Failed to create OrtSession")
        }
        self.handle = session
        self.environment = environment
    }

    public init(environment: ORTEnvironment, modelData: Data, options: ORTSessionOptions? = nil) throws {
        var session: UnsafeMutablePointer<OrtSession>?
        try modelData.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else {
                throw ORTError.invalidArgument("Model data is empty")
            }
            try ORTAPI.check(ORTAPI.api.pointee.CreateSessionFromArray(
                environment.handle,
                base,
                buffer.count,
                options?.handle,
                &session
            ))
        }
        guard let session else {
            throw ORTError.invalidArgument("Failed to create OrtSession")
        }
        self.handle = session
        self.environment = environment
    }

    deinit {
        ORTAPI.api.pointee.ReleaseSession(handle)
    }

    public func inputNames() throws -> [String] {
        var count: Int = 0
        try ORTAPI.check(ORTAPI.api.pointee.SessionGetInputCount(handle, &count))
        if count == 0 { return [] }

        let allocator = try ORTAPI.defaultAllocator()
        var results: [String] = []
        results.reserveCapacity(count)

        for index in 0..<count {
            var value: UnsafeMutablePointer<CChar>?
            try ORTAPI.check(ORTAPI.api.pointee.SessionGetInputName(handle, index, allocator, &value))
            guard let value else {
                throw ORTError.invalidArgument("Failed to read input name at index \(index)")
            }
            results.append(String(cString: value))
            try ORTAPI.check(ORTAPI.api.pointee.AllocatorFree(allocator, value))
        }

        return results
    }

    public func outputNames() throws -> [String] {
        var count: Int = 0
        try ORTAPI.check(ORTAPI.api.pointee.SessionGetOutputCount(handle, &count))
        if count == 0 { return [] }

        let allocator = try ORTAPI.defaultAllocator()
        var results: [String] = []
        results.reserveCapacity(count)

        for index in 0..<count {
            var value: UnsafeMutablePointer<CChar>?
            try ORTAPI.check(ORTAPI.api.pointee.SessionGetOutputName(handle, index, allocator, &value))
            guard let value else {
                throw ORTError.invalidArgument("Failed to read output name at index \(index)")
            }
            results.append(String(cString: value))
            try ORTAPI.check(ORTAPI.api.pointee.AllocatorFree(allocator, value))
        }

        return results
    }

    public func run(inputs: [String: ORTValue], outputNames: [String]? = nil) throws -> [String: ORTValue] {
        let inputNames = inputs.keys.sorted()
        let inputValues: [UnsafePointer<OrtValue>] = try inputNames.map { name in
            guard let value = inputs[name] else {
                throw ORTError.invalidArgument("Missing input value for \(name)")
            }
            return UnsafePointer(value.handle)
        }

        let outputs = outputNames ?? try self.outputNames()
        var outputHandles = Array<UnsafeMutablePointer<OrtValue>?>(repeating: nil, count: outputs.count)

        var inputNameCStrings = CStringArray(inputNames)
        var outputNameCStrings = CStringArray(outputs)
        defer {
            inputNameCStrings.deallocate()
            outputNameCStrings.deallocate()
        }

        try inputValues.withUnsafeBufferPointer { inputValueBuffer in
            try outputHandles.withUnsafeMutableBufferPointer { outputBuffer in
                try inputNameCStrings.withUnsafePointer { inputNamePtr in
                    try outputNameCStrings.withUnsafePointer { outputNamePtr in
                        try ORTAPI.check(ORTAPI.api.pointee.Run(
                            handle,
                            nil,
                            inputNamePtr,
                            inputValueBuffer.baseAddress,
                            inputValues.count,
                            outputNamePtr,
                            outputs.count,
                            outputBuffer.baseAddress
                        ))
                    }
                }
            }
        }

        var results: [String: ORTValue] = [:]
        results.reserveCapacity(outputs.count)
        for (name, handle) in zip(outputs, outputHandles) {
            guard let handle else {
                throw ORTError.invalidArgument("Missing output for \(name)")
            }
            results[name] = ORTValue(handle: handle)
        }
        return results
    }

    
}

public class ORTValue {
    let handle: UnsafeMutablePointer<OrtValue>

    init(handle: UnsafeMutablePointer<OrtValue>) {
        self.handle = handle
    }

    deinit {
        ORTAPI.api.pointee.ReleaseValue(handle)
    }

    public func tensorShape() throws -> [Int64] {
        var info: UnsafeMutablePointer<OrtTensorTypeAndShapeInfo>?
        try ORTAPI.check(ORTAPI.api.pointee.GetTensorTypeAndShape(handle, &info))
        guard let info else {
            throw ORTError.invalidArgument("Failed to get tensor type/shape info")
        }
        defer { ORTAPI.api.pointee.ReleaseTensorTypeAndShapeInfo(info) }

        var count: Int = 0
        try ORTAPI.check(ORTAPI.api.pointee.GetDimensionsCount(info, &count))
        if count == 0 { return [] }

        var dims = Array<Int64>(repeating: 0, count: count)
        try dims.withUnsafeMutableBufferPointer { buffer in
            try ORTAPI.check(ORTAPI.api.pointee.GetDimensions(info, buffer.baseAddress, count))
        }
        return dims
    }

    public func tensorData<Element: ORTTensorElement>(_ type: Element.Type = Element.self) throws -> [Element] {
        try ensureTensor(of: type)
        let shape = try tensorShape()
        let elementCount = shape.reduce(1, *)
        var raw: UnsafeMutableRawPointer?
        try ORTAPI.check(ORTAPI.api.pointee.GetTensorMutableData(handle, &raw))
        guard let raw else {
            throw ORTError.invalidArgument("Tensor data pointer is nil")
        }
        let typed = raw.bindMemory(to: Element.self, capacity: elementCount)
        return Array(UnsafeBufferPointer(start: typed, count: elementCount))
    }

    public func tensorDataCount() throws -> Int {
        let shape = try tensorShape()
        return shape.reduce(1, *)
    }

    private func ensureTensor<Element: ORTTensorElement>(of _: Element.Type) throws {
        var isTensor: Int32 = 0
        try ORTAPI.check(ORTAPI.api.pointee.IsTensor(handle, &isTensor))
        guard isTensor != 0 else {
            throw ORTError.invalidArgument("OrtValue is not a tensor")
        }

        var info: UnsafeMutablePointer<OrtTensorTypeAndShapeInfo>?
        try ORTAPI.check(ORTAPI.api.pointee.GetTensorTypeAndShape(handle, &info))
        guard let info else {
            throw ORTError.invalidArgument("Failed to get tensor type/shape info")
        }
        defer { ORTAPI.api.pointee.ReleaseTensorTypeAndShapeInfo(info) }

        var elementType = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED
        try ORTAPI.check(ORTAPI.api.pointee.GetTensorElementType(info, &elementType))
        guard elementType == Element.onnxType else {
            throw ORTError.invalidArgument("Tensor element type mismatch")
        }
    }
}

public final class ORTTensor<Element: ORTTensorElement>: ORTValue {
    public let shape: [Int64]
    private let storage: Data

    public init(_ data: [Element], shape: [Int64]) throws {
        let expectedCount = shape.reduce(1, *)
        guard expectedCount == data.count else {
            throw ORTError.invalidArgument("Data count (\(data.count)) does not match shape (\(shape))")
        }

        let byteCount = data.count * MemoryLayout<Element>.stride
        var dataCopy = data
        let storage = Data(bytes: &dataCopy, count: byteCount)

        var value: UnsafeMutablePointer<OrtValue>?
        try storage.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else {
                throw ORTError.invalidArgument("Tensor data is empty")
            }
            try shape.withUnsafeBufferPointer { shapeBuffer in
                try ORTAPI.check(ORTAPI.api.pointee.CreateTensorWithDataAsOrtValue(
                    ORTAPI.cpuMemoryInfo(),
                    UnsafeMutableRawPointer(mutating: base),
                    buffer.count,
                    shapeBuffer.baseAddress,
                    shape.count,
                    Element.onnxType,
                    &value
                ))
            }
        }

        guard let value else {
            throw ORTError.invalidArgument("Failed to create OrtValue for tensor")
        }

        self.shape = shape
        self.storage = storage
        super.init(handle: value)
    }
}

public protocol ORTTensorElement {
    static var onnxType: ONNXTensorElementDataType { get }
}

extension Float: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT }
}

extension Double: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE }
}

extension Int8: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8 }
}

extension UInt8: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8 }
}

extension Int16: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16 }
}

extension UInt16: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16 }
}

extension Int32: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 }
}

extension UInt32: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32 }
}

extension Int64: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 }
}

extension UInt64: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64 }
}

extension Bool: ORTTensorElement {
    public static var onnxType: ONNXTensorElementDataType { ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL }
}

private struct CStringArray {
    private var storage: [UnsafeMutablePointer<CChar>] = []
    private var pointers: [UnsafePointer<CChar>] = []
    private var lengths: [Int] = []

    init(_ strings: [String]) {
        storage.reserveCapacity(strings.count)
        pointers.reserveCapacity(strings.count)
        for string in strings {
            let utf8 = Array(string.utf8CString)
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
            utf8.withUnsafeBufferPointer { src in
                buffer.initialize(from: src.baseAddress!, count: utf8.count)
            }
            storage.append(buffer)
            pointers.append(UnsafePointer(buffer))
            lengths.append(utf8.count)
        }
    }

    mutating func deallocate() {
        for (index, pointer) in storage.enumerated() {
            pointer.deinitialize(count: lengths[index])
            pointer.deallocate()
        }
        storage.removeAll()
        pointers.removeAll()
        lengths.removeAll()
    }

    func withUnsafePointer<T>(_ body: (UnsafePointer<UnsafePointer<CChar>>?) throws -> T) rethrows -> T {
        try pointers.withUnsafeBufferPointer { buffer in
            try body(buffer.baseAddress)
        }
    }
}

private func withOrtPath<T>(_ path: String, _ body: (UnsafePointer<ORTCHAR_T>) throws -> T) rethrows -> T {
    #if os(Windows)
    let utf16 = Array(path.utf16) + [0]
    return try utf16.withUnsafeBufferPointer { buffer in
        try buffer.baseAddress!.withMemoryRebound(to: ORTCHAR_T.self, capacity: buffer.count) { rebound in
            try body(rebound)
        }
    }
    #else
    return try path.withCString { cstr in
        let rebound = UnsafeRawPointer(cstr).assumingMemoryBound(to: ORTCHAR_T.self)
        return try body(rebound)
    }
    #endif
}
