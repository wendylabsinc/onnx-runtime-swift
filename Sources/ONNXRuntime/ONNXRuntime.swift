public enum ONNXRuntime {
    public static let buildFlavor: String = {
        #if ORT_CUDA
        return "cuda"
        #elseif ORT_ROCM
        return "rocm"
        #else
        return "cpu"
        #endif
    }()
}
