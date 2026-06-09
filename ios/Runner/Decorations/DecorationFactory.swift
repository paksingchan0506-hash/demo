import Foundation

class DecorationFactory {
    static func create(type: String?) -> FaceDecoration {
        guard let t = type?.lowercased() else { return MaskDecoration() }
        switch t {
        case "upper_face": return UpperFaceDecoration()
        case "full_face": return FullFaceDecoration()
        case "mask": fallthrough
        default: return MaskDecoration()
        }
    }
}
