import Foundation
import ONNXRuntime

func usage() {
    let message = """
    BasicInference usage:
      --model <path>         Path to .onnx model (required)
      --input <csv>          Comma-separated float values (optional)
      --shape <csv>          Comma-separated shape (optional; default is [input.count])
      --output <name>        Output name to fetch (optional)

    Examples:
      swift run BasicInference --model /path/model.onnx
      swift run BasicInference --model /path/model.onnx --input 1,2,3,4 --shape 2,2
    """
    print(message)
}

func parseFloats(_ value: String) throws -> [Float] {
    let parts = value.split(separator: ",")
    guard !parts.isEmpty else { return [] }
    return try parts.map { part in
        guard let number = Float(part) else {
            throw ORTError.invalidArgument("Invalid float: \(part)")
        }
        return number
    }
}

func parseInt64s(_ value: String) throws -> [Int64] {
    let parts = value.split(separator: ",")
    guard !parts.isEmpty else { return [] }
    return try parts.map { part in
        guard let number = Int64(part) else {
            throw ORTError.invalidArgument("Invalid dimension: \(part)")
        }
        return number
    }
}

let args = CommandLine.arguments
var modelPath: String?
var inputValues: [Float] = []
var shape: [Int64] = []
var outputName: String?

var index = 1
while index < args.count {
    let arg = args[index]
    switch arg {
    case "--model":
        guard index + 1 < args.count else { usage(); exit(1) }
        modelPath = args[index + 1]
        index += 2
    case "--input":
        guard index + 1 < args.count else { usage(); exit(1) }
        do {
            inputValues = try parseFloats(args[index + 1])
        } catch {
            print(error)
            exit(1)
        }
        index += 2
    case "--shape":
        guard index + 1 < args.count else { usage(); exit(1) }
        do {
            shape = try parseInt64s(args[index + 1])
        } catch {
            print(error)
            exit(1)
        }
        index += 2
    case "--output":
        guard index + 1 < args.count else { usage(); exit(1) }
        outputName = args[index + 1]
        index += 2
    default:
        index += 1
    }
}

guard let modelPath else {
    usage()
    exit(1)
}

do {
    let env = try ORTEnvironment()
    let options = try ORTSessionOptions()
    let session = try ORTSession(environment: env, modelPath: modelPath, options: options)

    print("ONNX Runtime version: \(ORT.versionString)")
    print("Inputs: \(try session.inputNames())")
    print("Outputs: \(try session.outputNames())")

    if !inputValues.isEmpty {
        if shape.isEmpty {
            shape = [Int64(inputValues.count)]
        }

        let inputNames = try session.inputNames()
        guard inputNames.count == 1 else {
            print("Model has \(inputNames.count) inputs; provide explicit mapping.")
            exit(1)
        }

        let inputTensor = try ORTTensor<Float>(inputValues, shape: shape)
        let outputs = try session.run(inputs: [(inputNames[0], inputTensor)], outputNames: outputName.map { [$0] })

        for (name, value) in outputs {
            let outShape = try value.tensorShape()
            let outValues: [Float] = try value.tensorData()
            print("Output \(name): shape=\(outShape) values=\(outValues)")
        }
    }
} catch {
    print("Error: \(error)")
    exit(1)
}
